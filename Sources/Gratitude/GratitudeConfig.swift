import SwiftUI

/// All content + behaviour for the Gratitude modal and buttons.
/// Same struct used at `configure(...)` and at `present(config:)`.
/// Any field left `nil` falls back to the next layer
/// (override → global config → `.default`).
public struct GratitudeConfig: Sendable {

	/// Navigation-bar / window title.
	public var navigationTitle: String?

	/// Modal headline. Shown bold + large.
	public var headline: String?

	/// Modal body copy. One short paragraph; markdown not parsed.
	public var message: String?

	/// Optional extra paragraph rendered below the tip buttons.
	public var footer: String?

	/// Emoji rendered as the header artwork.
	public var emoji: String?

	/// Asset name in the caller's bundle (e.g. an illustration).
	public var imageName: String?

	/// SF Symbol name used when no `imageName` is set.
	public var systemImageName: String?

	/// Accent colour for the modal artwork. nil = system accent.
	public var accent: Color?

	/// Track per-product and aggregate tip counts in UserDefaults.
	/// When ON, the modal optionally shows total tips, and
	/// `Gratitude.shared.tipCount(for:)` / `totalGiftCount()` return
	/// real numbers. Counts are stored under `gratitude.count.<product>`
	/// and `gratitude.count.__total`.
	public var trackGiftCounts: Bool?

	public init(
		navigationTitle: String? = nil,
		headline: String? = nil,
		message: String? = nil,
		footer: String? = nil,
		emoji: String? = nil,
		imageName: String? = nil,
		systemImageName: String? = nil,
		accent: Color? = nil,
		trackGiftCounts: Bool? = nil
	) {
		self.navigationTitle = navigationTitle
		self.headline = headline
		self.message = message
		self.footer = footer
		self.emoji = emoji
		self.imageName = imageName
		self.systemImageName = systemImageName
		self.accent = accent
		self.trackGiftCounts = trackGiftCounts
	}

	/// Library defaults. Bottom of the merge stack — any field still nil after
	/// merging override + global with this gets the value below.
	public static let `default` = GratitudeConfig(
		navigationTitle: "Gratitude",
		headline: "Send us a tip",
		message: "It runs on our time and your goodwill. If it's been useful, send us a little tip.",
		footer: nil,
		emoji: "🎁",
		imageName: nil,
		systemImageName: nil,
		accent: .pink,
		trackGiftCounts: false
	)

	/// Returns a new config where every nil field in `self` is filled from `fallback`.
	public func merged(over fallback: GratitudeConfig) -> GratitudeConfig {
		GratitudeConfig(
			navigationTitle: self.navigationTitle ?? fallback.navigationTitle,
			headline:        self.headline        ?? fallback.headline,
			message:         self.message         ?? fallback.message,
			footer:          self.footer          ?? fallback.footer,
			emoji:           self.emoji           ?? fallback.emoji,
			imageName:       self.imageName       ?? fallback.imageName,
			systemImageName: self.systemImageName ?? fallback.systemImageName,
			accent:          self.accent          ?? fallback.accent,
			trackGiftCounts: self.trackGiftCounts ?? fallback.trackGiftCounts
		)
	}

	/// Fully-resolved config: any nil fields filled from `.default`.
	public var resolved: GratitudeConfig {
		merged(over: .default)
	}

	/// Returns a copy with the closure's mutations applied.
	public func modified(_ transform: (inout GratitudeConfig) -> Void) -> GratitudeConfig {
		var copy = self
		transform(&copy)
		return copy
	}
}
