import Foundation
import StoreKit

/// StoreKit 2 wrapper. Hydrates products from App Store, runs the
/// transaction-update listener, exposes purchase state to SwiftUI.
@MainActor
public final class GratitudeStore: ObservableObject {

	/// product id → StoreKit Product. Populated by loadProducts().
	@Published public private(set) var products: [String: Product] = [:]

	/// True while loadProducts() is in flight.
	@Published public private(set) var isLoading: Bool = false

	/// The product id currently being purchased, or nil. UI uses this to
	/// disable other buttons and show a spinner on the active one.
	@Published public private(set) var purchasingProduct: String? = nil

	/// Most recent error from loadProducts() or purchase(). Surfaced by UI.
	@Published public private(set) var lastError: GratitudeError? = nil

	private var tiers: [GiftTier] = []
	private var trackCounts: Bool = false
	private var listenerTask: Task<Void, Never>?

	internal init() {}

	deinit { listenerTask?.cancel() }

	/// Called by Gratitude.configure(). Loads products + starts listener.
	internal func start(tiers: [GiftTier], trackCounts: Bool) {
		self.tiers = tiers
		self.trackCounts = trackCounts

		listenerTask?.cancel()
		listenerTask = Task { [weak self] in
			await self?.listenForTransactions()
		}
		Task { await loadProducts() }
	}

	/// Re-fetch product metadata + prices. Called automatically by start();
	/// can be invoked manually if the App Store was unreachable at launch.
	public func loadProducts() async {
		isLoading = true
		defer { isLoading = false }
		let ids = tiers.map(\.product)
		do {
			let fetched = try await Product.products(for: ids)
			self.products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
		} catch {
			self.lastError = .productNotLoaded(ids.joined(separator: ", "))
			print("[Gratitude] product load failed: \(error)")
		}
	}

	/// Initiate a purchase. Caller doesn't need to manage purchasingProduct
	/// or finish() — both are handled here.
	@discardableResult
	public func purchase(tier: GiftTier) async -> PurchaseResult {
		guard let product = products[tier.product] else {
			let err = GratitudeError.productNotLoaded(tier.product)
			self.lastError = err
			return .failed(err)
		}

		purchasingProduct = tier.product
		defer { purchasingProduct = nil }

		do {
			let result = try await product.purchase()
			switch result {
			case .success(let verification):
				switch verification {
				case .verified(let transaction):
					await transaction.finish()
					if trackCounts { incrementGiftCount(for: tier.product) }
					Gratitude.shared.onPurchase?(tier)
					return .success(tier: tier)
				case .unverified(_, let verificationError):
					return .failed(verificationError)
				}
			case .userCancelled:
				return .userCancelled
			case .pending:
				return .pending
			@unknown default:
				return .failed(GratitudeError.unknownPurchaseResult)
			}
		} catch {
			return .failed(error)
		}
	}

	// MARK: Transaction listener

	/// Long-running task that watches for refunds, family-sharing-revoked,
	/// out-of-band purchases, etc. Each verified transaction is finished.
	private func listenForTransactions() async {
		for await update in Transaction.updates {
			switch update {
			case .verified(let transaction):
				await transaction.finish()
			case .unverified:
				continue
			}
		}
	}

	// MARK: Gift count tracking (UserDefaults; off unless config opts in)

	private static let totalKey = "gratitude.count.__total"
	private func key(for product: String) -> String { "gratitude.count.\(product)" }

	public func tipCount(for product: String) -> Int {
		guard trackCounts else { return 0 }
		return UserDefaults.standard.integer(forKey: key(for: product))
	}

	public func totalGiftCount() -> Int {
		guard trackCounts else { return 0 }
		return UserDefaults.standard.integer(forKey: Self.totalKey)
	}

	private func incrementGiftCount(for product: String) {
		let ud = UserDefaults.standard
		let perKey = key(for: product)
		ud.set(ud.integer(forKey: perKey) + 1, forKey: perKey)
		ud.set(ud.integer(forKey: Self.totalKey) + 1, forKey: Self.totalKey)
	}
}
