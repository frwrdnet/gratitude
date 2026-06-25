# Gratitude

A tiny gift and gratitude Swift Package for SwiftUI, UIKit, and AppKit apps. Configure a
handful of consumable IAP tiers, drop a button in your UI, and let users
toss you a thank-you through StoreKit 2.

- **Platforms:** iOS 18+, macOS 15+
- **Dependencies:** none (StoreKit 2 only)
- **License:** MIT

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/frwrdnet/Gratitude.git", from: "0.1.0")
```

Then add `"Gratitude"` to the `dependencies` of any target that needs it.

Or in Xcode: **File → Add Package Dependencies…** → paste the repo URL.

## Setup

In App Store Connect (or your local `.storekit` file), create one consumable
in-app purchase per gift tier. Then, early in your app lifecycle, hand the
products to `Gratitude.shared`:

```swift
import Gratitude

Gratitude.shared.configure(
    tiers: [
        GiftTier(product: "com.example.app.gifts.tiny",  emoji: "☕", sortOrder: 0),
        GiftTier(product: "com.example.app.gifts.small", emoji: "🥪", sortOrder: 1),
        GiftTier(product: "com.example.app.gifts.medium",  emoji: "🍱", sortOrder: 2),
        GiftTier(product: "com.example.app.gifts.large",   emoji: "🎉", sortOrder: 3),
    ],
    config: GratitudeConfig(
        headline: "Enjoying the app?",
        message: "It runs on my time and your goodwill. If it's been useful, drop a little gift.",
        systemImageName: "heart.fill",
        accent: .pink,
        trackGiftCounts: false
    )
)
```

## Presenting the sheet

Programmatic, anywhere — no view modifier required:

```swift
Button("Send a gift") {
    Gratitude.shared.present()
}
```

On iOS this presents a `UIHostingController`, on macOS an `NSHostingController`.

## Individual gift buttons

If you'd rather wire your own UI, drop in a single-tier button.

**SwiftUI:**

```swift
GiftButton(product: tier.product)                  // default style
GiftButton(product: tier.product, style: MyStyle()) // custom ButtonStyle
```

**UIKit:**

```swift
let button = GiftButtonUIKit(product: tier.product)
view.addSubview(button)
```

**AppKit:**

```swift
let button = GiftButtonAppKit(product: tier.product)
view.addSubview(button)
```

## Counting gifts (optional)

Set `trackGiftCounts: true` in `GratitudeConfig` to persist a per-product
counter across launches. Read with:

```swift
Gratitude.shared.giftCount(for: "com.example.app.gifts.small")
Gratitude.shared.totalGiftCount()
```

## License

MIT — see [LICENSE](LICENSE).
