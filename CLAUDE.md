# Beacon — Claude Code Guide

This file captures the non-obvious conventions that make this codebase coherent. Read it before touching any file.

## Design system — mandatory rules

1. **Tokens, not literals.** Every color, font, spacing value, and radius comes from `BeaconDesignSystem.swift`. No hardcoded hex codes, point sizes, or pixel values anywhere in views. The only exceptions are documented in the usage guide (`Docs/beacon-usage-guide.md`): the 1.5px focus border, the `.white` on-accent text, and the 0.4 disabled opacity.

2. **Sage means progress.** `Color.beaconAccent` is reserved for affordances that signal forward motion: the chart line, the payoff date stat, the $0 final row, and primary action buttons. Never use it for decorative chrome or selection states.

3. **Amber means attention.** `Color.beaconAttention` is the only other chromatic color. It is paired with an SF Symbol — color alone is never the sole signal (accessibility requirement).

4. **`beaconTextTertiary` is not for readable copy.** The design system documents it as deliberately failing WCAG AA. Use it only for placeholders and metadata the user does not need to read.

5. **Motion is restrained.** `BeaconMotion.appearance` fires only for content appearing for the first time. State updates, field edits, and error appearances are instant. Do not add animations beyond this.

## Domain layer rules

- **No SwiftUI or Combine in `Domain/`.** The calculator, validator, and all models import only `Foundation`.
- **`Decimal` throughout the engine.** Never convert to `Double` for computation. `NSDecimalNumber(decimal:).doubleValue` is acceptable only for SwiftUI Charts axis rendering (a display concern, not a calculation).
- **One formatter, not many.** All currency and date formatting goes through `BeaconFormatters` in `Domain/Formatting/`. Never allocate `NumberFormatter` or `DateFormatter` inline in a view.
- **Validator before calculator.** The calculator only ever runs with a fully validated `RepaymentInput`. `InputValidator.buildInput(from:)` returns `nil` on invalid input — callers must validate first.

## Architecture

- **`BeaconViewModel` is the single source of truth.** It owns form inputs, validation state, touch tracking, and the computed plan. No other observable state exists except `PayoffChartView.selectedRow` (chart-local).
- **Field views are thin.** Each field wrapper (`BalanceField`, `APRField`, etc.) only configures a `Field` component and calls `viewModel.markTouched(_:)` on focus loss. No business logic.
- **Errors gate on touch.** `viewModel.error(for:)` returns `nil` until the field has been blurred or Calculate has been pressed. The `canCalculate` derived property runs unconditionally — button enablement is never gated.

## Known issues

See `Docs/beacon-results-from-phase-4.md` and the Next Steps review (`Docs/20260724 Next Steps.md`) for the full issue list.

## Manual TODOs (require human action)

- **App icon** — `Assets.xcassets/AppIcon.appiconset` has empty slots for light, dark, and tinted 1024×1024 images. These must be provided before App Store submission.
- **AccentColor** — `Assets.xcassets/AccentColor.colorset` is empty. Set it to sage: light `#5C8A6F`, dark `#7BA88C` (matches `Color.beaconAccent`).
- **Privacy manifest** — Add `PrivacyInfo.xcprivacy`. Beacon collects nothing, so the manifest is simple, but it is now required for submission.
