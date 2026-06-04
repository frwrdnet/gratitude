import Foundation

public enum PurchaseResult: Sendable {
	case success(tier: GiftTier)
	case userCancelled
	case pending
	case failed(Error)
}
