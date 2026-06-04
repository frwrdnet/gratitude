import SwiftUI

/// The full tip-jar modal. Use one of:
///   • Call `Gratitude.shared.present()` from any code path
///     (uses `UIHostingController` / `NSHostingController` under the hood)
///   • Embed `GratitudeSheet()` inside your own `.sheet { }` if you want
///     SwiftUI-managed presentation
public struct GratitudeSheet: View {

	@ObservedObject private var store = Gratitude.shared.store
	@ObservedObject private var gratitude = Gratitude.shared
	@Environment(\.dismiss) private var environmentDismiss

	private let onDismiss: (() -> Void)?

	public init(onDismiss: (() -> Void)? = nil) {
		self.onDismiss = onDismiss
	}

	/// Use the injected closure if provided (programmatic presentation
	/// via `Gratitude.shared.present()`), otherwise fall back to the
	/// SwiftUI environment dismiss (declarative `.sheet { }` usage).
	private func performDismiss() {
		if let onDismiss { onDismiss() }
		else { environmentDismiss() }
	}

	public var body: some View {
		let config = gratitude.config

		NavigationStack {
			VStack {
				Spacer(minLength: 0)

				VStack(spacing: 20) {
					artwork(config: config)

					VStack(spacing: 8) {
						Text(config?.headline ?? "Support development")
							.font(.title2.weight(.semibold))
							.multilineTextAlignment(.center)
						Text(config?.message ?? "")
							.font(.body)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.fixedSize(horizontal: false, vertical: true)
					}

					if store.isLoading {
						ProgressView("Loading…").padding(.vertical, 8)
					} else if gratitude.tiers.isEmpty {
						Text("No tip tiers configured.")
							.font(.callout)
							.foregroundStyle(.secondary)
					} else {
						VStack(spacing: 12) {
							ForEach(gratitude.tiers) { tier in
								GiftButton(product: tier.product)
									.controlSize(.large)
									.frame(maxWidth: .infinity)
							}
						}
						.padding(.top, 4)
					}

					if let config, config.trackGiftCounts {
						let total = gratitude.totalGiftCount()
						if total > 0 {
							Text("You've tipped \(total) time\(total == 1 ? "" : "s") — thank you 🙏")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}
				.padding(28)
				.frame(maxWidth: 440)

				Spacer(minLength: 0)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(role: .cancel) {
						performDismiss()
					} label: {
						Image(systemName: "xmark")
							.fontWeight(.semibold)
					}
				}
			}
			#if os(iOS)
			.toolbarBackground(.hidden, for: .navigationBar)
			.navigationBarTitleDisplayMode(.inline)
			#endif
		}
		#if os(macOS)
		.frame(minWidth: 380, minHeight: 360)
		#endif
	}

	@ViewBuilder
	private func artwork(config: GratitudeConfig?) -> some View {
		if let name = config?.imageName {
			Image(name)
				.resizable()
				.scaledToFit()
				.frame(height: 96)
		} else if let symbol = config?.systemImageName {
			Image(systemName: symbol)
				.font(.system(size: 56, weight: .regular))
				.foregroundStyle(config?.accent ?? .accentColor)
				.padding(.bottom, 4)
		} else {
			Image(systemName: "heart.fill")
				.font(.system(size: 56, weight: .regular))
				.foregroundStyle(config?.accent ?? .accentColor)
				.padding(.bottom, 4)
		}
	}
}
