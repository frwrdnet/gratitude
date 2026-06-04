import SwiftUI

/// Caller-supplied content + behavior for the Gratitude modal and buttons.
public struct GratitudeConfig: Sendable {

	/// Modal headline. Shown bold + large.
	public var headline: String

	/// Modal body copy. One short paragraph; markdown not parsed.
	public var message: String

	/// Asset name in the caller's bundle (e.g. an illustration). Optional.
	public var imageName: String?

	/// SF Symbol fallback if `imageName` is nil. Optional.
	public var systemImageName: String?

	/// Override the accent color in the modal / buttons. nil = system accent.
	public var accent: Color?

	/// Track per-product and aggregate tip counts in UserDefaults.
	/// OFF by default. When ON, the modal optionally shows total tips,
	/// and `Gratitude.shared.tipCount(for:)` / `totalTipCount()` return
	/// real numbers. Counts are stored under
	/// `gratitude.count.<product>` and `gratitude.count.__total`.
	public var trackTipCounts: Bool

	public init(
		headline: String,
		message: String,
		imageName: String? = nil,
		systemImageName: String? = nil,
		accent: Color? = nil,
		trackTipCounts: Bool = false
	) {
		self.headline = headline
		self.message = message
		self.imageName = imageName
		self.systemImageName = systemImageName
		self.accent = accent
		self.trackTipCounts = trackTipCounts
	}
}
