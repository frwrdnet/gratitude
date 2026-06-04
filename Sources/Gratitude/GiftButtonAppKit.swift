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
		spinner.controlSize = .small
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
