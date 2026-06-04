import Foundation

public enum PurchaseResult: Sendable {
	case success(tier: TipTier)
	case userCancelled
	case pending
	case failed(Error)
}
