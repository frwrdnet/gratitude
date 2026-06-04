import Foundation

public enum GratitudeError: LocalizedError {
	case notConfigured
	case productNotLoaded(String)
	case tierNotFound(String)
	case unknownPurchaseResult

	public var errorDescription: String? {
		switch self {
		case .notConfigured:
			return "Gratitude.configure(...) was never called."
		case .productNotLoaded(let id):
			return "Product not loaded from App Store: \(id)."
		case .tierNotFound(let id):
			return "No configured tier for product: \(id)."
		case .unknownPurchaseResult:
			return "Unknown StoreKit purchase result."
		}
	}
}
