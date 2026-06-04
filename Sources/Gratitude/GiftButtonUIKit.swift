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
