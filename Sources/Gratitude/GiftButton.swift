import SwiftUI

/// A single tap-to-tip button. Drop anywhere; reads price + label from
/// the configured tier and StoreKit product.
///
/// Use the default look:
///     GiftButton(product: tier.product)
///
/// Or pass any `ButtonStyle` you like:
///     GiftButton(product: tier.product, style: .borderedProminent)
///     GiftButton(product: tier.product, style: MyButtonStyle())
public struct GiftButton<S: ButtonStyle>: View {

	public let product: String
	public let label: String?
	public let style: S

	@ObservedObject private var store = Gratitude.shared.store
	@State private var alertText: String?

	public init(product: String, label: String? = nil, style: S) {
		self.product = product
		self.label = label
		self.style = style
	}

	public var body: some View {
		Button(action: tap) {
			HStack(spacing: 10) {
				if let emoji = tier?.emoji { Text(emoji) }
				Text(label ?? displayName)
					.lineLimit(1)
				Spacer(minLength: 8)
				Text(priceText)
					.monospacedDigit()
				if store.purchasingProduct == product {
					ProgressView()
						.controlSize(.mini)
				}
			}
			.contentShape(Rectangle())
		}
		.disabled(isDisabled)
		.buttonStyle(style)
		.alert("Gift failed", isPresented: errorAlert) {
			Button("OK") { alertText = nil }
		} message: {
			Text(alertText ?? "")
		}
	}

	private var tier: GiftTier? {
		Gratitude.shared.tiers.first(where: { $0.product == product })
	}

	private var displayName: String {
		if let p = store.products[product] { return p.displayName }
		return "Gift"
	}

	private var priceText: String {
		store.products[product]?.displayPrice ?? "—"
	}

	private var isDisabled: Bool {
		store.products[product] == nil
			|| store.purchasingProduct != nil
	}

	private var errorAlert: Binding<Bool> {
		Binding(
			get: { alertText != nil },
			set: { if !$0 { alertText = nil } }
		)
	}

	private func tap() {
		guard let tier else {
			alertText = "No tier configured for \(product)."
			return
		}
		Task {
			let result = await store.purchase(tier: tier)
			switch result {
			case .success, .userCancelled, .pending:
				break
			case .failed(let e):
				alertText = e.localizedDescription
			}
		}
	}
}

// MARK: Convenience init — picks DefaultGratitudeButtonStyle when no style is passed

public extension GiftButton where S == DefaultGratitudeButtonStyle {
	init(product: String, label: String? = nil) {
		self.init(product: product, label: label, style: DefaultGratitudeButtonStyle())
	}
}

// MARK: Default style — pill-shaped, accent-tinted

public struct DefaultGratitudeButtonStyle: ButtonStyle {
	public init() {}

	public func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.subheadline.weight(.medium))
			.foregroundStyle(.primary)
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				(configuration.role == .destructive ? Color.red : Color.secondary.opacity(0.2))
					.opacity(configuration.isPressed ? 0.7 : 1.0)
			)
			.clipShape(RoundedRectangle(cornerRadius: 100))
	}
}


#if canImport(AppKit)
import AppKit
internal import Combine

/// AppKit-native tip button — the analogue of SwiftUI's `GiftButton`.
///
///     let btn = GiftButtonAppKit(product: "net.frwrd.app.tips.small")
///     stackView.addArrangedSubview(btn)
///
/// Auto-updates title + price + enabled state from the Gratitude store.
/// Clicking initiates the purchase; alerts and the spinner are handled
/// internally.
///
/// Available on macOS (pure AppKit). For Mac Catalyst apps use
/// `GiftButtonUIKit` from the UIKit module.
@MainActor
public final class GiftButtonAppKit: NSButton {
	
	/// The App Store Connect product identifier this button buys.
	public let product: String
	
	/// Optional title override. If nil, uses the StoreKit product display name.
	public let customLabel: String?
	
	private let spinner: NSProgressIndicator
	private var cancellables = Set<AnyCancellable>()
	
	public init(product: String, label: String? = nil) {
		self.product = product
		self.customLabel = label
		
		self.spinner = NSProgressIndicator()
		spinner.style = .spinning
		spinner.controlSize = .mini
		spinner.isDisplayedWhenStopped = false
		spinner.translatesAutoresizingMaskIntoConstraints = false
		
		super.init(frame: .zero)
		
		setupAppearance()
		addSubview(spinner)
		NSLayoutConstraint.activate([
			spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
			spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
		])
		
		target = self
		action = #selector(handleClick)
		
		observeStore()
		refresh()
	}
	
	@available(*, unavailable)
	public required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
	
	private func setupAppearance() {
		bezelStyle = .rounded
		isBordered = true
		alignment = .center
	}
	
	private func observeStore() {
		let store = Gratitude.shared.store
		store.$products
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in self?.refresh() }
			.store(in: &cancellables)
		store.$purchasingProduct
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in self?.refresh() }
			.store(in: &cancellables)
	}
	
	private func refresh() {
		let store = Gratitude.shared.store
		let product = store.products[self.product]
		let tier = Gratitude.shared.tiers.first(where: { $0.product == self.product })
		
		let title: String
		if let customLabel { title = customLabel }
		else if let product { title = product.displayName }
		else { title = "Gift" }
		let price = product?.displayPrice ?? "—"
		let prefix = tier.map { "\($0.emoji)  " } ?? ""
		
		self.title = "\(prefix)\(title)   \(price)"
		
		let isPurchasingThis = store.purchasingProduct == self.product
		if isPurchasingThis {
			spinner.startAnimation(nil)
		} else {
			spinner.stopAnimation(nil)
		}
		
		isEnabled = product != nil && store.purchasingProduct == nil
	}
	
	@objc private func handleClick() {
		guard let tier = Gratitude.shared.tiers.first(where: { $0.product == self.product }) else {
			presentAlert("No tier configured for \(self.product).")
			return
		}
		Task { [weak self] in
			let result = await Gratitude.shared.store.purchase(tier: tier)
			if case .failed(let err) = result {
				await MainActor.run { self?.presentAlert(err.localizedDescription) }
			}
		}
	}
	
	private func presentAlert(_ message: String) {
		let alert = NSAlert()
		alert.messageText = "Gift failed"
		alert.informativeText = message
		alert.alertStyle = .warning
		alert.addButton(withTitle: "OK")
		if let win = NSApp.keyWindow {
			alert.beginSheetModal(for: win) { _ in }
		} else {
			alert.runModal()
		}
	}
}
#endif


#if canImport(UIKit)
import UIKit
internal import Combine

/// UIKit-native tip button — the analogue of SwiftUI's `GiftButton`.
///
///     let btn = GiftButtonUIKit(product: "net.frwrd.app.tips.small")
///     view.addSubview(btn)
///
/// Auto-updates title + price + enabled state from the Gratitude store.
/// Tapping initiates the purchase; alerts and the activity indicator
/// are handled internally.
///
/// Available on iOS and Mac Catalyst.
@MainActor
public final class GiftButtonUIKit: UIButton {
	
	/// The App Store Connect product identifier this button buys.
	public let product: String
	
	/// Optional title override. If nil, uses the StoreKit product display name.
	public let customLabel: String?
	
	private var cancellables = Set<AnyCancellable>()
	
	public init(product: String, label: String? = nil) {
		self.product = product
		self.customLabel = label
		super.init(frame: .zero)
		setupAppearance()
		observeStore()
		refresh()
	}
	
	@available(*, unavailable)
	public required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
	
	private func setupAppearance() {
		var config = UIButton.Configuration.bordered()
		config.title = ""
		config.subtitle = ""
		config.titleAlignment = .leading
		config.imagePadding = 8
		configuration = config
		addTarget(self, action: #selector(handleTap), for: .touchUpInside)
	}
	
	private func observeStore() {
		let store = Gratitude.shared.store
		store.$products
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in self?.refresh() }
			.store(in: &cancellables)
		store.$purchasingProduct
			.receive(on: RunLoop.main)
			.sink { [weak self] _ in self?.refresh() }
			.store(in: &cancellables)
	}
	
	private func refresh() {
		let store = Gratitude.shared.store
		let product = store.products[self.product]
		let tier = Gratitude.shared.tiers.first(where: { $0.product == self.product })
		
		let title: String
		if let customLabel { title = customLabel }
		else if let product { title = product.displayName }
		else { title = "Gift" }
		let price = product?.displayPrice ?? "—"
		let prefix = tier.map { "\($0.emoji)  " } ?? ""
		
		var conf = configuration ?? .bordered()
		conf.title = "\(prefix)\(title)"
		conf.subtitle = price
		conf.showsActivityIndicator = (store.purchasingProduct == self.product)
		configuration = conf
		
		isEnabled = product != nil && store.purchasingProduct == nil
	}
	
	@objc private func handleTap() {
		guard let tier = Gratitude.shared.tiers.first(where: { $0.product == self.product }) else {
			presentAlert("No tier configured for \(self.product).")
			return
		}
		Task { [weak self] in
			let result = await Gratitude.shared.store.purchase(tier: tier)
			if case .failed(let err) = result {
				await MainActor.run { self?.presentAlert(err.localizedDescription) }
			}
		}
	}
	
	private func presentAlert(_ message: String) {
		guard let scene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive })
				?? UIApplication.shared.connectedScenes.first as? UIWindowScene
		else { return }
		guard let window = scene.windows.first(where: \.isKeyWindow)
				?? scene.windows.first else { return }
		var top: UIViewController? = window.rootViewController
		while let p = top?.presentedViewController { top = p }
		let alert = UIAlertController(title: "Gift failed", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		top?.present(alert, animated: true)
	}
}
#endif
