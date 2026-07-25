# Beacon

A credit card payoff calculator for iOS. Enter your balance, APR, and repayment goal — Beacon produces a month-by-month amortization plan with chart visualization.

**Zero third-party dependencies.** All computation is on-device with no data transmitted anywhere.

## Requirements

- Xcode 16+
- iOS 17.0+ deployment target
- No external packages or CocoaPods

## Build & Run

1. Open `Beacon.xcodeproj` in Xcode
2. Select a simulator or device (iOS 17+)
3. Press ⌘R

## Run Tests

```
xcodebuild test -scheme Beacon -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press ⌘U in Xcode.

## Architecture

```
Beacon/
├── App/                    BeaconRootView — root container, owns ViewModel
├── DesignSystem/           Tokens (colors, type, spacing) + reusable components
│   └── Components/
├── Domain/
│   ├── Calculation/        AmortizationCalculator — pure Decimal engine
│   ├── Formatting/         BeaconFormatters — unified currency/date formatting
│   ├── Models/             Value types (PayoffPlan, RepaymentInput, etc.)
│   └── Validation/         InputValidator — pure validator, no UI dependency
└── Features/
    └── PayoffPlanner/
        ├── InputForm/      Field views wired to BeaconViewModel
        └── Results/        Chart, summary stats, amortization table
```

### Key principles

- **`Decimal` throughout the engine** — no `Double` in financial computation
- **Domain layer imports only `Foundation`** — no SwiftUI, no Combine
- **Design tokens, not literals** — all colors/fonts/spacing via `BeaconDesignSystem.swift`
- **Single `BeaconViewModel`** — one source of truth for all UI state

## Privacy

Beacon collects no data. All inputs stay on-device and are not persisted between sessions.

## Docs

- `Docs/beacon-prd.md` — product requirements
- `Docs/beacon-tech-spec.md` — technical specification
- `Docs/beacon-usage-guide.md` — design system usage guide
