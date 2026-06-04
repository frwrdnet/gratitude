import Foundation

/// One tap-to-tip option. Mirror an App Store Connect consumable IAP.
public struct GiftTier: Identifiable, Hashable, Sendable {

	/// The App Store Connect product identifier
	/// (e.g. "net.frwrd.nabu.tip.small").
	public let product: String

	/// A short emoji or glyph rendered next to the price.
	public let emoji: String

	/// Sort position in the modal — lower = first. Ties broken by product id.
	public let sortOrder: Int

	public init(product: String, emoji: String, sortOrder: Int = 0) {
		self.product = product
		self.emoji = emoji
		self.sortOrder = sortOrder
	}

	public var id: String { product }
}
