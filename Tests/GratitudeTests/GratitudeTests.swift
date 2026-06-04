import XCTest
@testable import Gratitude

final class GratitudeTests: XCTestCase {

	@MainActor
	func test_configure_sortsTiersByOrderThenId() {
		Gratitude.shared.configure(
			tiers: [
				TipTier(product: "b", emoji: "🥪", sortOrder: 1),
				TipTier(product: "a", emoji: "☕", sortOrder: 0),
				TipTier(product: "c", emoji: "🎉", sortOrder: 1),
			],
			config: GratitudeConfig(headline: "h", message: "m")
		)
		XCTAssertEqual(Gratitude.shared.tiers.map(\.product), ["a", "b", "c"])
	}

	@MainActor
	func test_tipCount_offByDefault() {
		Gratitude.shared.configure(
			tiers: [TipTier(product: "x", emoji: "🪙")],
			config: GratitudeConfig(headline: "h", message: "m")
		)
		XCTAssertEqual(Gratitude.shared.tipCount(for: "x"), 0)
		XCTAssertEqual(Gratitude.shared.totalTipCount(), 0)
	}
}
