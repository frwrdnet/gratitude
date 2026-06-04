import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Top-level façade. Configure once at app launch; drop a `TipButton`
/// anywhere, or call `present()` from any code path to show the modal —
/// no view-tree modifier required.
@MainActor
public final class Gratitude: ObservableObject {

	public static let shared = Gratitude()

	/// Tiers in sort order. Empty until configure() is called.
	public internal(set) var tiers: [TipTier] = []

	/// Caller-supplied content + behavior. nil until configure().
	public internal(set) var config: GratitudeConfig?

	/// The StoreKit 2 wrapper. Public so callers can observe loading /
	/// purchasing state directly in their own SwiftUI views if they want
	/// to skip TipButton / GratitudeSheet.
	public let store: GratitudeStore

	/// Optional callback fired after a successful tip. Use for analytics,
	/// custom thank-yous, or unlocking cosmetic perks.
	public var onPurchase: ((TipTier) -> Void)?

	private init() {
		self.store = GratitudeStore()
	}

	/// Call exactly once at app launch (e.g. in your `App.init`).
	public func configure(tiers: [TipTier], config: GratitudeConfig) {
		self.tiers = tiers.sorted {
			if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
			return $0.product < $1.product
		}
		self.config = config
		store.start(tiers: self.tiers, trackCounts: config.trackTipCounts)
	}

	// MARK: Tip count read-out (only meaningful if config.trackTipCounts)

	public func tipCount(for product: String) -> Int {
		store.tipCount(for: product)
	}

	public func totalTipCount() -> Int {
		store.totalTipCount()
	}

	// MARK: Programmatic presentation

	/// Present the tip-jar modal from anywhere in your app.
	/// iOS: presents a `UIHostingController` as a half-sheet over the
	/// topmost view controller.
	/// macOS: presents an `NSHostingController` as a sheet on the key
	/// window, or opens a small standalone window if no key window is
	/// available.
	public func present() {
		#if os(iOS)
		presentOnIOS()
		#elseif os(macOS)
		presentOnMacOS()
		#endif
	}

	#if os(iOS)
	private func presentOnIOS() {
		// Find the foreground-active scene's key window, then walk up
		// any presented controllers to land on top of existing modals
		// (Settings sheet, share sheet, etc.).
		guard let scene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive })
			?? UIApplication.shared.connectedScenes.first as? UIWindowScene
		else { return }
		guard let window = scene.windows.first(where: \.isKeyWindow)
			?? scene.windows.first else { return }

		var top: UIViewController? = window.rootViewController
		while let presented = top?.presentedViewController { top = presented }

		let host = UIHostingController(rootView: GratitudeSheet())
		host.rootView = GratitudeSheet { [weak host] in
			host?.dismiss(animated: true)
		}
		host.modalPresentationStyle = .pageSheet
		if let sheet = host.sheetPresentationController {
			sheet.detents = [.large()] //[.medium(), .large()]
			sheet.prefersGrabberVisible = true
		}
		top?.present(host, animated: true)
	}
	#endif

	#if os(macOS)
	private func presentOnMacOS() {
		let host = NSHostingController(rootView: GratitudeSheet())
		host.rootView = GratitudeSheet { [weak host] in
			host?.dismiss(nil)
		}
		if let contentVC = NSApp.keyWindow?.contentViewController {
			contentVC.presentAsSheet(host)
		} else {
			// No key window — open a small standalone window instead.
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
				styleMask: [.titled, .closable, .fullSizeContentView],
				backing: .buffered,
				defer: false
			)
			window.contentViewController = host
			window.title = config?.headline ?? "Send a Tip"
			window.center()
			window.isReleasedWhenClosed = false
			window.makeKeyAndOrderFront(nil)
		}
	}
	#endif
}
