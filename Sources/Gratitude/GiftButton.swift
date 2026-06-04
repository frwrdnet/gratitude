import SwiftUI

/// A single tap-to-tip button. Drop anywhere; reads price + label from
/// the configured tier and StoreKit product.
///
/// Use the default look:
///     GiftButton(product: tier.product)
///
/// Or pass any `ButtonStyle` you like:
///     GiftButton(product: tier.product, style: .borderedProminent)
///     GiftButton(product: tier.product, style: MyButtonStyle())
public struct GiftButton<S: ButtonStyle>: View {

	public let product: String
	public let label: String?
	public let style: S

	@ObservedObject private var store = Gratitude.shared.store
	@State private var alertText: String?

	public init(product: String, label: String? = nil, style: S) {
		self.product = product
		self.label = label
		self.style = style
	}

	public var body: some View {
		Button(action: tap) {
			HStack(spacing: 10) {
				if let emoji = tier?.emoji { Text(emoji) }
				Text(label ?? displayName)
					.lineLimit(1)
				Spacer(minLength: 8)
				Text(priceText)
					.monospacedDigit()
				if store.purchasingProduct == product {
					ProgressView()
						.controlSize(.small)
				}
			}
			.contentShape(Rectangle())
		}
		.disabled(isDisabled)
		.buttonStyle(style)
		.alert("Gift failed", isPresented: errorAlert) {
			Button("OK") { alertText = nil }
		} message: {
			Text(alertText ?? "")
		}
	}

	private var tier: GiftTier? {
		Gratitude.shared.tiers.first(where: { $0.product == product })
	}

	private var displayName: String {
		if let p = store.products[product] { return p.displayName }
		return "Gift"
	}

	private var priceText: String {
		store.products[product]?.displayPrice ?? "—"
	}

	private var isDisabled: Bool {
		store.products[product] == nil
			|| store.purchasingProduct != nil
	}

	private var errorAlert: Binding<Bool> {
		Binding(
			get: { alertText != nil },
			set: { if !$0 { alertText = nil } }
		)
	}

	private func tap() {
		guard let tier else {
			alertText = "No tier configured for \(product)."
			return
		}
		Task {
			let result = await store.purchase(tier: tier)
			switch result {
			case .success, .userCancelled, .pending:
				break
			case .failed(let e):
				alertText = e.localizedDescription
			}
		}
	}
}

// MARK: Convenience init — picks DefaultGratitudeButtonStyle when no style is passed

public extension GiftButton where S == DefaultGratitudeButtonStyle {
	init(product: String, label: String? = nil) {
		self.init(product: product, label: label, style: DefaultGratitudeButtonStyle())
	}
}

// MARK: Default style — pill-shaped, accent-tinted

public struct DefaultGratitudeButtonStyle: ButtonStyle {
	public init() {}

	public func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.subheadline.weight(.medium))
			.foregroundStyle(.primary)
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(
				(configuration.role == .destructive ? Color.red : Color.secondary.opacity(0.2))
					.opacity(configuration.isPressed ? 0.7 : 1.0)
			)
			.clipShape(RoundedRectangle(cornerRadius: 100))
	}
}
