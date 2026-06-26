import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: Per-call presentation overrides

/// Optional per-presentation overrides for the Gratitude sheet. Any field
/// left `nil` falls back to the value from `GratitudeConfig` (set at
/// `configure(...)`), and from there to a sensible default.
public struct GratitudeOverrides: Sendable {
	/// Navigation-bar / window title. `nil` = empty.
	public var navigationTitle: String?
	/// SF Symbol name to render as the artwork.
	public var systemImageName: String?
	/// Asset name in the caller's bundle (takes precedence over SF Symbol).
	public var imageName: String?
	/// Headline shown bold below the artwork.
	public var headline: String?
	/// Body copy shown below the headline.
	public var message: String?
	/// Optional extra paragraph rendered below the tip buttons.
	public var footer: String?

	public init(
		navigationTitle: String? = nil,
		systemImageName: String? = nil,
		imageName: String? = nil,
		headline: String? = nil,
		message: String? = nil,
		footer: String? = nil
	) {
		self.navigationTitle = navigationTitle
		self.systemImageName = systemImageName
		self.imageName = imageName
		self.headline = headline
		self.message = message
		self.footer = footer
	}
}

/// Top-level façade. Configure once at app launch; drop a `GiftButton`
/// anywhere, or call `present()` from any code path to show the modal —
/// no view-tree modifier required.
@MainActor
public final class Gratitude: ObservableObject {

	public static let shared = Gratitude()

	/// Tiers in sort order. Empty until configure() is called.
	public internal(set) var tiers: [GiftTier] = []

	/// Caller-supplied content + behavior. nil until configure().
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
	public func configure(tiers: [GiftTier], config: GratitudeConfig) {
		self.tiers = tiers.sorted {
			if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
			return $0.product < $1.product
		}
		self.config = config
		store.start(tiers: self.tiers, trackCounts: config.trackGiftCounts)
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
	/// `overrides` lets you customise the sheet's nav title, icon,
	/// headline, body text, and an optional footer paragraph per-call.
	/// Any field left `nil` falls back to the global config.
	public func present(
		width: CGFloat? = nil,
		height: CGFloat? = nil,
		overrides: GratitudeOverrides? = nil
	) {
		#if os(iOS)
		presentOnIOS(overrides: overrides)
		#elseif os(macOS)
		presentOnMacOS(width: width, height: height, overrides: overrides)
		#endif
	}

	#if os(iOS)
	private func presentOnIOS(overrides: GratitudeOverrides?) {
		guard let scene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive })
			?? UIApplication.shared.connectedScenes.first as? UIWindowScene
		else { return }
		guard let window = scene.windows.first(where: \.isKeyWindow)
			?? scene.windows.first else { return }

		var top: UIViewController? = window.rootViewController
		while let presented = top?.presentedViewController { top = presented }

		let host = UIHostingController(rootView: GratitudeSheet(overrides: overrides))
		host.rootView = GratitudeSheet(overrides: overrides) { [weak host] in
			host?.dismiss(animated: true)
		}
		host.modalPresentationStyle = .pageSheet
		if let sheet = host.sheetPresentationController {
			sheet.detents = [.large()]
			sheet.prefersGrabberVisible = true
		}
		top?.present(host, animated: true)
	}
	#endif

	#if os(macOS)
	private func presentOnMacOS(width: CGFloat?, height: CGFloat?, overrides: GratitudeOverrides?) {
		let w = width ?? 440
		let h = height ?? 540

		let host = NSHostingController(rootView: GratitudeSheet(overrides: overrides))
		host.rootView = GratitudeSheet(overrides: overrides) { [weak host] in
			host?.dismiss(nil)
		}
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
			window.title = overrides?.navigationTitle
				?? overrides?.headline
				?? config?.headline
				?? "Send a Gift"
			window.center()
			window.isReleasedWhenClosed = false
			window.makeKeyAndOrderFront(nil)
		}
	}
	#endif
}