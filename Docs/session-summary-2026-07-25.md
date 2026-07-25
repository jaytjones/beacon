# Session Summary — 25 July 2026

**Source document:** `Docs/20260724 Next Steps.md`
**Commits this session:** `afc2825`, `a01d90c`, `19733e4`
**Build status:** ✅ Clean build, all targets compiling

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

### Test updates ✅
- `BeaconViewModelTests` updated to reflect the ViewModel refactor.
- Two new tests added: `test_errorNotVisible_untilFieldTouched` and `test_calculate_exposesAllErrors`.

---

## What was NOT completed (next session)

### Stage 3 remainder
- **§2.8 Stale-notice race:** The `hasStaleResults` boolean flag can flip `true` after a fresh calculation if the debounced sink fires late. The fix is to snapshot the inputs used for the current plan and compare rather than using a boolean. Left for next session.

### Stage 4 — Tests and accessibility
- **§4.4:** ~20 validator tests via Swift Testing `@Test(arguments:)` — `parseDecimal` edge cases, APR/months boundary values, `byPaymentTermAlert` projection. Estimated: ~1 session.
- **§4.4:** Three real UI test flows (happy path, insufficient-payment recovery, recalculation) replacing the template stubs. Estimated: ~1 session.
- **§4.4:** `.xctestplan` to synchronize CI and Xcode test runs.
- **§5 (Accessibility):** Chart `accessibilityLabel` + `AXChartDescriptor`.
- **§5 (Accessibility):** Dynamic Type: `@ScaledMetric` for `AmortizationTableMetrics.dateColumnWidth` + stacked row layout at `.accessibility1+`.
- **§5 (Accessibility):** `AccessibilityNotification.Announcement` when results appear after calculation.
- **§5 (Accessibility):** Reduce Motion handling for `BeaconMotion.appearance` transitions.

### Stage 5 — Code quality
- **§3.2:** Single-pass validation — have `validate()` return the built `RepaymentInput` alongside the result so `buildInput(from:)` doesn't re-run the full validation pass.
- **§3.3:** Remaining dead code: `BeaconMotion.subtleChange` (acceptable, but flag it); `Field.textContentType` parameter has no call-site usage.
- **§3.4:** `SWIFT_STRICT_CONCURRENCY = complete` → Swift 6 language mode.
- **§3.4:** `@Observable` migration to replace the Combine pipeline.
- **§3.5:** String Catalog (`.xcstrings`) — if i18n is ever planned.
- **§6:** Documentation reconciliation pass (PRD/tech-spec drift table in the review doc).

### Stage 6 — Launch prep
- **Manual (human required):** App icon — `Assets.xcassets/AppIcon.appiconset` has empty slots for light, dark, and tinted 1024×1024 images.
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
| Stage 4 (tests + accessibility) | 1–2 |
| Stage 5 (code quality) | 1 |
| Stage 6 (launch prep, excluding manual items) | 1 |
| **Total** | **3–4 sessions** |

---

## Resuming next session

Start by reading this document, then:
1. Run the tests to confirm green: `xcodebuild test -scheme Beacon`
2. Continue with **Stage 4** — validator tests are the highest-priority gap
3. The review document (`Docs/20260724 Next Steps.md`) remains the authoritative source for all remaining items with exact file/line references
