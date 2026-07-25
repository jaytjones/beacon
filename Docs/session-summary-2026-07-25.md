# Session Summary — 25 July 2026

**Source document:** `Docs/20260724 Next Steps.md`
**Commits this session:** `afc2825`, `a01d90c`, `19733e4`, `7c19f53`, `22fce2a`
**Build status:** ✅ Clean build, all targets compiling, 101/101 tests passing

---

## What was completed

### Stage 1 — Repository hygiene ✅
- `.gitignore` added (xcuserdata, DerivedData, .DS_Store, build artifacts)
- `Beacon.xcodeproj/xcuserdata/` removed from git tracking
- `README.md` created (build instructions, architecture map, zero-dependency claim)
- `CLAUDE.md` created (design system rules, domain layer rules, manual TODOs)

### Stage 2 — Blocking defects ✅
- **§1.1 Fixed:** `isCalculating` removed from `BeaconViewModel` entirely. The synchronous calculation never needed a loading state; the property caused the Calculate button to lock permanently on the error path. `CalculateButton.swift` updated accordingly.
- **§1.2 Fixed:** Push/CloudKit entitlements stripped from `Beacon.entitlements`; `UIBackgroundModes` removed from `Info.plist`.
- **§1.4 Fixed:** `Item.swift` deleted (SwiftData template debris).
- **§1.5 Partial:** Deployment target set to iOS 17.0 on all three targets (was: app 17.6, tests 26.4). Build environment still requires the iOS 17 simulator to be installed locally.
- **§4.4 Partial:** `BeaconTests.swift` renamed to `AmortizationCalculatorTests.swift`.

### Stage 3 — UX correctness ✅
- **§2.1 Fixed:** Touched-state validation gating. `BeaconViewModel` now tracks `touchedFields: Set<InputField>` and `hasAttemptedCalculation`. `error(for:)` returns nil until the field has been blurred or Calculate pressed. All four field wrappers call `viewModel.markTouched(_:)` via the new `onFocusLost` callback on `Field`.
- **§2.2 Fixed:** Keyboard toolbar with Done button added to `InputFormView`. `.scrollDismissesKeyboard(.interactively)` added to `BeaconRootView`'s ScrollView.
- **§2.3 Fixed:** Chart tooltip moved from VStack sibling to `.overlay(alignment: .top)` on the Chart — no more layout jump on tap.
- **§2.4 Fixed:** Chart tap handler migrated from `.chartBackground` to `.chartOverlay`. Removed unused `balance` binding and duplicate `nearest` computation.
- **§2.5 Fixed:** `axisLabelCount` restored to responsive logic (≤12 months → all, ≤60 → 6, else 4).
- **§2.6 Fixed:** `isHero: true` enabled on Payoff Date stat. `SummaryStatCard` moved to its own design system file and updated with `@ScaledMetric` so the hero font scales with Dynamic Type.
- **§2.7 Fixed:** `BeaconFormatters` created at `Domain/Formatting/BeaconFormatters.swift` using modern `.formatted` APIs. All five formatting call sites in `SummaryRow`, `ChartTooltipOverlay`, and `PayoffChartView` routed through it — no more `Decimal→Double` round-trips or inline formatter allocations.
- **§2.8 Partial:** `DisclaimerFooter` updated from `beaconTextTertiary` to `beaconTextSecondary`. Dead `showRecalculateBar` property and stale comments removed from `BeaconRootView`.

### Stage 4 — Tests ✅ (commit `7c19f53`)
- **Validator tests:** `BeaconTests/InputValidatorTests.swift` replaced with 55+ parametrized Swift Testing cases across 8 `@Suite` structs: `parseDecimal` edge cases (greedy parsing behaviour documented), balance/APR/months/payment boundary values, business-logic alert ordering (`insufficientPayment` fires before `termExceedsMax`), byMonths feasibility, and `buildInput` round-trips. All green.
- **UI tests:** `BeaconUITests/BeaconUITests.swift` replaced with 3 real XCUIAutomation flows: happy-path byMonths calculation, insufficient-payment error recovery (alert appears → corrected payment → results appear), and stale-results notice (edit after calculation → stale notice → recalculate → notice clears).
- **101/101 tests passing** across all three test suites.

### Stage 4 — Accessibility ✅ (commit `22fce2a`)
- **Chart audio graph:** `PayoffChartView` gains `AXChartDescriptorRepresentable` via private `PayoffChartDescriptor` struct. VoiceOver can navigate each month's remaining balance as an audio graph. Chart view also has an `.accessibilityLabel` summary string ("Balance over time chart. N months. Starting balance $X.").
- **VoiceOver announcement:** `BeaconRootView` posts `AccessibilityNotification.Announcement` (via `.onChange(of: viewModel.plan?.payoffDate)`) whenever results are calculated or recalculated — reads months, total interest, and payoff date.
- **Reduce Motion:** `@Environment(\.accessibilityReduceMotion)` in `BeaconRootView` gates both `BeaconMotion.appearance` fade-ins. When Reduce Motion is on, results and stale-notice appear instantly.
- **Dynamic Type — table:** `AmortizationRowView` uses `@ScaledMetric private var scaledDateWidth: CGFloat = 76` at normal sizes. At `.accessibility1+`, the row switches to a stacked VStack: "Month N — Jan 2026" header + two HStacks of labeled amounts (Payment/Interest, Principal/Balance). `AmortizationTableView` hides the column header at accessibility sizes (rows are self-describing) and scales its own header date column with `@ScaledMetric`.

---

## What was NOT completed (next session)

### Stage 3 remainder
- **§2.8 Stale-notice race:** The `hasStaleResults` boolean flag can flip `true` after a fresh calculation if the debounced sink fires late. The fix is to snapshot the inputs used for the current plan and compare rather than using a boolean. Left for Stage 5 refactor.

### Stage 4 remainder
- **§4.4:** `.xctestplan` to synchronize CI and Xcode test runs. Low priority — can be deferred to Stage 6 alongside the CI workflow.

### Stage 5 — Code quality
- **§3.2:** Single-pass validation — have `validate()` return the built `RepaymentInput` alongside the result so `buildInput(from:)` doesn't re-run the full validation pass.
- **§3.4:** `SWIFT_STRICT_CONCURRENCY = complete` → Swift 6 language mode.
- **§3.4:** `@Observable` migration to replace the Combine pipeline in `BeaconViewModel`.
- **§3.5:** String Catalog (`.xcstrings`) — if i18n is ever planned.
- **§6:** Documentation reconciliation pass (PRD/tech-spec drift table in the review doc).

### Stage 6 — Launch prep
- **Manual (human required):** App icon — user has a 1024×1024 PNG (PNG is the correct format). Drop into the three `AppIcon.appiconset` slots in Assets.xcassets (light, dark, tinted). If only one image, use the same PNG for all three slots.
- **Manual (human required):** AccentColor — `Assets.xcassets/AccentColor.colorset` is empty; set to sage: light `#5C8A6F` / dark `#7BA88C`.
- **§4.2:** GitHub Actions CI workflow (build + test on push/PR).
- **§4.3:** `swift-format` config + SwiftLint config; run once on whole tree.
- Instruments profiling at 360 rows on an older device (iPhone XR).
- `PrivacyInfo.xcprivacy` privacy manifest (required for App Store submission).
- App Store listing, screenshots, privacy questionnaire.

---

## Estimated remaining work

| Stage | Estimated sessions |
|---|---|
| Stage 5 (code quality) | 1 |
| Stage 6 (launch prep, excluding manual items) | 1 |
| **Total** | **2 sessions** |

---

## Resuming next session

Start by reading this document, then:
1. Run the tests to confirm green: `xcodebuild test -scheme Beacon`
2. Continue with **Stage 5** — single-pass validation is the cleanest starting point, then strict concurrency, then `@Observable` migration
3. The review document (`Docs/20260724 Next Steps.md`) remains the authoritative source for all remaining items with exact file/line references
