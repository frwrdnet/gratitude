import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Top-level façade. Configure once at app launch (or rely on `.default`);
/// drop a `GiftButton` anywhere, or call `present()` from any code path to
/// show the modal — no view-tree modifier required.
@MainActor
public final class Gratitude: ObservableObject {

	public static let shared = Gratitude()

	/// Tiers in sort order. Empty until configure() is called.
	public internal(set) var tiers: [GiftTier] = []

	/// Caller-supplied content + behavior. nil until configure() is called;
	/// in that case the sheet falls back entirely to `GratitudeConfig.default`.
	public internal(set) var config: GratitudeConfig?

	/// The StoreKit 2 wrapper. Public so callers can observe loading /
	/// purchasing state directly in their own SwiftUI views if they want
	/// to skip TipButton / GratitudeSheet.
	public let store: GratitudeStore

	/// Optional callback fired after a successful tip. Use for analytics,
	/// custom thank-yous, or unlocking cosmetic perks.
	public var onPurchase: ((GiftTier) -> Void)?

	private init() {
		self.store = GratitudeStore()
	}

	/// Call exactly once at app launch (e.g. in your `App.init`).
	/// Any field left nil in `config` falls back to `GratitudeConfig.default`.
	public func configure(tiers: [GiftTier], config: GratitudeConfig = GratitudeConfig()) {
		self.tiers = tiers.sorted {
			if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
			return $0.product < $1.product
		}
		self.config = config
		store.start(tiers: self.tiers, trackCounts: config.trackGiftCounts ?? false)
	}

	// MARK: Gift count read-out (only meaningful if config.trackGiftCounts)

	public func giftCount(for product: String) -> Int {
		store.tipCount(for: product)
	}

	public func totalGiftCount() -> Int {
		store.totalGiftCount()
	}

	// MARK: Programmatic presentation

	/// Present the tip-jar modal from anywhere in your app.
	///
	/// On macOS, `width`/`height` set the size of the sheet (or the
	/// standalone-window fallback). Pass `nil` to use the defaults
	/// of 440×540. Note that `GratitudeSheet` enforces a minimum of
	/// 380×360 internally, so smaller values are clamped up.
	///
	/// On iOS the sheet uses system detents, so `width`/`height` are
	/// ignored.
	///
	/// `config` is a per-call override. Any field left nil falls back to the
	/// global config (set via `configure(...)`), and from there to
	/// `GratitudeConfig.default`.
	public func present(
		width: CGFloat? = nil,
		height: CGFloat? = nil,
		config: GratitudeConfig? = nil
	) {
		#if os(iOS)
		presentOnIOS(config: config)
		#elseif os(macOS)
		presentOnMacOS(width: width, height: height, config: config)
		#endif
	}

	#if os(iOS)
	private func presentOnIOS(config: GratitudeConfig?) {
		guard let scene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive })
			?? UIApplication.shared.connectedScenes.first as? UIWindowScene
		else { return }
		guard let window = scene.windows.first(where: \.isKeyWindow)
			?? scene.windows.first else { return }

		var top: UIViewController? = window.rootViewController
		while let presented = top?.presentedViewController { top = presented }

		let host = UIHostingController(rootView: GratitudeSheet(config: config))
		host.rootView = GratitudeSheet(
			config: config,
			onDismiss: { [weak host] in host?.dismiss(animated: true) }
		)
		host.modalPresentationStyle = .pageSheet
		if let sheet = host.sheetPresentationController {
			sheet.detents = [.large()]
			sheet.prefersGrabberVisible = true
		}
		top?.present(host, animated: true)
	}
	#endif

	#if os(macOS)
	private func presentOnMacOS(width: CGFloat?, height: CGFloat?, config: GratitudeConfig?) {
		let w = width ?? 440
		let h = height ?? 540

		let host = NSHostingController(rootView: GratitudeSheet(config: config))
		host.rootView = GratitudeSheet(
			config: config,
			onDismiss: { [weak host] in host?.dismiss(nil) }
		)
		host.preferredContentSize = NSSize(width: w, height: h)

		if let contentVC = NSApp.keyWindow?.contentViewController {
			contentVC.presentAsSheet(host)
		} else {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: w, height: h),
				styleMask: [.titled, .closable, .fullSizeContentView],
				backing: .buffered,
				defer: false
			)
			window.contentViewController = host
			let resolved = (config ?? GratitudeConfig())
				.merged(over: self.config ?? GratitudeConfig())
				.resolved
			window.title = resolved.navigationTitle ?? "Send a tip"
			window.center()
			window.isReleasedWhenClosed = false
			window.makeKeyAndOrderFront(nil)
		}
	}
	#endif
}
