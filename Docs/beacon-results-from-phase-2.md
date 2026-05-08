# Beacon — Phase 2 Results

**Phase:** 2 (Core Loop)
**Date completed:** May 2026
**Reference docs:** `Docs/beacon-prd.md`, `Docs/beacon-tech-spec.md`, `Docs/beacon-usage-guide.md`, `Docs/beacon-results-from-phase-1.md`

This document captures everything that was built, decided, or discovered during Phase 2 that **isn't** in the tech spec or usage guide — so Phase 3 (and any future contributors) can pick up without re-deriving the context. The tech spec and usage guide remain the source of truth for what was specified; this is the diff between specified and built.

Phase 2 broke into four sub-phases:

* **2.0** — five design system components in `DesignSystem/Components/`
* **2.1** — nine input-form components in `Features/PayoffPlanner/InputForm/`
* **2.2** — validator catch for the byMonths catastrophic case from `KNOWN_ISSUES.md`
* **2.3** — two amortization table components in `Features/PayoffPlanner/Results/`
* **2.4** — end-to-end wire-up in `BeaconRootView`

---

## What's done

| Component | Path | Status |
| --- | --- | --- |
| Design system components | `Beacon/DesignSystem/Components/*.swift` | All five from usage guide — `Field`, `PrimaryButton`, `MenuField`, `InlineNotice`, `DisclaimerFooter` |
| Input form components | `Beacon/Features/PayoffPlanner/InputForm/*.swift` | Nine files — four field wrappers, mode selector, date picker, calculate button, inline alert, composer |
| Validator catastrophic catch | `Beacon/Domain/Validation/InputValidator.swift` | Extended with `byMonthsFeasibilityError` private helper + new field-level branch |
| Validator tests | `BeaconTests/InputValidatorTests.swift` | First dedicated validator test file. One test pinning the byMonths catastrophic case |
| Amortization table | `Beacon/Features/PayoffPlanner/Results/AmortizationTableView.swift`, `AmortizationRowView.swift` | Header + LazyVStack of rows; full-bleed layout |
| Root view | `Beacon/App/BeaconRootView.swift` | Replaces placeholder. Owns the `BeaconViewModel` as `@StateObject`; composes title → form → results → disclaimer |

**28 tests total, all green** (27 from Phase 1 + 1 new in Phase 2.2). The app builds and runs end-to-end on iPhone simulator: enter inputs, tap Calculate, see the amortization table render with the BeaconMotion.appearance fade-in.

---

## Architectural decisions made during the build

These were chosen during Phase 2 implementation, not specified upfront. Recording them so they're not silently re-litigated in Phase 3+.

### `Field`'s error parameter is `String?`, not `FieldError?`

Initial draft of `Field.swift` took `FieldError?` for the inline error parameter, assuming the domain type would flow through to the design system. The build broke immediately — `BeaconViewModel.error(for:)` returns `String?`, not `FieldError?`. Diagnosed mid-phase, fixed by decoupling.

This is actually better architecture. `Field` is a design system primitive and shouldn't import domain types like `FieldError` (which carries `field: InputField` and an `id: UUID` — neither needed to render an error). The fix landed in 2.1 alongside the field components and unblocked the rest of the phase.

**Implication for Phase 3+:** any new design system component that needs to communicate validation errors should take `String?`, not the domain type. Domain-aware wrapping happens at the feature layer (e.g., `BalanceField` passes `viewModel.error(for: .balance)` through).

### `RepaymentModeSelector` uses a custom Binding through `switchMode(to:)`

The Phase 1 doc flagged that the mode toggle should call `viewModel.switchMode(to:)` (the side-effecting method that clears the inactive field's text and validation error), not bind directly to `$repaymentMode` (which would skip the side effect). Implemented as a custom Binding constructed inline:

```
private var modeBinding: Binding<RepaymentMode> {
    Binding(
        get: { viewModel.repaymentMode },
        set: { viewModel.switchMode(to: $0) }
    )
}
```

Considered using `.onChange(of:)` on a direct binding instead — rejected because `switchMode` would re-trigger `onChange`, creating a feedback-loop concern. Custom binding is cleaner and intent-revealing.

### `MenuField` is generic over `Hashable Value`

A single component drives both the start-month dropdown (`Int` 1–12) and the start-year dropdown (`Int` current+10 range) via a `display: (Value) -> String` closure. Considered making two domain-specific components (`MonthDropdown`, `YearDropdown`) — rejected because the layout, accessibility, and trigger styling are identical. Generic is cleaner.

### `StartDatePicker` uses per-dropdown labels, not a parent "Start date" header

PRD §F1 frames "start date" as a single conceptual entity with two dropdowns. The visual treatment could either be (A) one header "Start date" above two unlabeled dropdowns, or (B) two separately-labeled dropdowns "Month" and "Year". Chose B because:

* `MenuField` already renders its own label — keeping the API consistent
* "Month" and "Year" are unambiguous in the form context (they appear after Balance, APR, and the mode toggle)
* VoiceOver gets cleaner labels per dropdown

The trade-off is a small deviation from the PRD's framing. Documented in the file's header comment.

### `AmortizationRowView` shows five visible columns, not six (Month # dropped)

PRD §F3 specifies six columns: `Month #, Month Name + Year, Payment Amount, Interest Paid, Principal Paid, Remaining Balance`. On iPhone widths the six-column layout was tight enough to push currency cells into `.minimumScaleFactor` shrinking even at modest balances. After spec analysis (~420pt of content vs ~311pt of available row width on iPhone 8 / iPhone X), dropped Month # from the visible row.

The `monthNumber` is preserved in the accessibility label per tech spec §6.2 ("Month N, [month name year], payment ..."), so VoiceOver users hear the same content. Sighted users lose the row index — but the date column already conveys position, and row order is its own visual cue.

Documented as a deliberate v1 deviation in the row component's header comment.

### `AmortizationTableView` is full-bleed

Rows extend edge-to-edge so alternating row backgrounds reach the screen edges (the standard look for native iOS finance apps). Internal row padding (`AmortizationTableMetrics.rowHorizontalPadding = BeaconSpacing.lg`) provides the content margin.

**Implication:** the parent (currently `BeaconRootView`) must not wrap the table in additional horizontal padding. The other sections (title, form, disclaimer) get `.padding(.horizontal, BeaconLayout.screenMargin)` selectively; the table doesn't.

### `AmortizationTableMetrics` enum holds shared layout constants

Six layout constants (`dateColumnWidth`, `columnGap`, `rowVerticalPadding`, `rowHorizontalPadding`) are referenced by both `AmortizationRowView` and `AmortizationTableView`'s header. Defined once in `AmortizationRowView.swift` since the row owns the per-row layout; the header conforms to match. Prevents column-drift between header and rows.

### `byMonthsFeasibilityError` checks against the actual start-month days, not worst-case 31

The catastrophic case from `KNOWN_ISSUES.md` only manifests at 31-day starting months. Two ways to detect it:

* **Worst-case** (always check against 31 days) — conservative, would surface false positives where the actual start month happens to be 30 or 28 days
* **Actual start-month days** — matches the calculator's behavior exactly; same balance + APR + months passes for some start months and fails for others

Chose actual. The user's experience now matches the math: if the calculator would empty-plan their inputs, the validator catches it; if the calculator would amortize them, the validator allows it. No false positives.

The check fires more broadly than the 360-month example in the issue doc — it correctly catches `(10000, 18%, 300 months, January start)` and similar combinations where the derived payment is below first-month interest. This is intentional. The known-issues doc used 360 as an example; the underlying condition (payment can't cover interest) is what defines catastrophic.

### Currency formatting via `Decimal.formatted(.currency(code: "USD"))`

iOS 15+ built-in API on `Decimal` (and `Numeric` more broadly). No formatter helper file needed. USD is hardcoded — v1 is US-only per PRD §8. If multi-currency lands in v1.1, the seam is whoever calls `.formatted(.currency(code:))` — pull the code from a higher-level config.

This decision applies in three places: `InlineAlertView` (for the suggested-minimum payment in the insufficient-payment alert), `AmortizationRowView` (for all four currency columns), and any future formatted display of money values.

### No animation on field swap, alert appearance, or recalculation updates

Per usage guide rule #5 ("Animate appearance, not change"), `BeaconMotion.appearance` is reserved for three specific events listed in the design system: RecalculateBar slide-in, StaleResultsNotice fade-in, and Results section reveal. Everything else is intentionally instant.

In Phase 2 this meant:

* Swapping `MonthsField` ↔ `MonthlyPaymentField` when the user toggles repayment mode is instant. The native segmented Picker animates its own track at ~150ms; the field swap appears in the next frame.
* `InlineAlertView` appearing/disappearing as the user changes inputs is instant.
* Inline field errors appearing/disappearing as validation runs is instant.
* The Phase 2.4 `BeaconRootView`'s `.animation(BeaconMotion.appearance, value: viewModel.plan != nil)` watches `plan != nil` (Bool), not `plan` itself — so the animation fires only on the nil → non-nil transition. When Phase 3 adds the recalculate flow, plan-to-plan updates won't re-animate.

### `PrimaryButton`'s loading state holds the title's footprint

`ZStack` with `Text(title).opacity(isLoading ? 0 : 1)` and a conditionally-rendered `ProgressView` overlay. The button doesn't resize when loading toggles. Considered swapping the label entirely — rejected because button width can shift, which would jiggle the form layout below.

### Two usage-site literal exceptions in `PrimaryButton`

`Color.white` for the button label on sage fill, and `0.4` for the disabled-state opacity. Both are parallel to `Field`'s 1.5px focused-border width, which the usage guide already documents as a narrow special case with no token. User confirmed "keep as-is" rather than introducing `.beaconOnAccent` and `BeaconOpacity.disabled` tokens for v1. Both are candidates for tokenization in v1.x if they recur elsewhere.

---

## Additions and extensions beyond the tech spec

These weren't wrong in the spec — they just weren't fully specified, and decisions had to be made.

### `AmortizationTableMetrics` enum (new type)

Tech spec §3.2 component hierarchy lists `AmortizationTableView` and `AmortizationRowView × N`, but doesn't address how the header and rows share column dimensions. The enum is a small public-internal type that holds four CGFloat constants in one place. Prevents column-drift; trivial to refactor into its own file later if it grows.

### `byMonthsFeasibilityError` covers a broader class than the issue doc described

The known-issues doc describes the catastrophic case as "360 months at 18% APR with a 31-day starting month." The implemented check fires for any combination where the derived payment is ≤ the actual first-month interest, which catches more than just the 360-month example. Documented in the file header and in the updated `KNOWN_ISSUES.md` resolution section.

### `.minimumScaleFactor(0.7)` on currency cells

Tech spec doesn't specify what to do when content is too wide for a column (e.g., "$50,234.56" in a ~52pt column on iPhone 8). Chose graceful auto-shrink via `.minimumScaleFactor(0.7)` rather than truncation or abbreviation (`$50K`). This means very large balances will shrink in the table — acceptable for v1, but worth a Phase 4 polish review if user testing surfaces complaints.

### Inline `#Preview` blocks on every component

Every design system component and most feature components have `#Preview` blocks for SwiftUI canvas. Useful during development for visual confirmation of states (e.g., `Field`'s default / focused / error states, `PrimaryButton`'s default / disabled / loading states). Not in the spec; not part of test runs.

### Validator copy for the byMonths catastrophic case

PRD §7 doesn't include the new error case — it predates the Phase 2.2 fix. The chosen message is *"At this APR, your balance won't be paid off in this many months. Try a longer term."* — modeled on the existing PRD pattern of "state the problem briefly + try [doing X]" used in the insufficient-payment and term-exceeds-max alert copy.

---

## Interpretations of ambiguous spec language

Where the spec was open to reading, here's how we read it.

### "Table scrolls independently on mobile without hijacking the main page scroll" (PRD §F3)

Interpreted as "the table is part of the main scroll, not nested in its own scroll view that would steal gestures." Aligns with the tech spec §3.2 component hierarchy showing `AmortizationTableView` inside the parent `ScrollView`. The implementation has a single `ScrollView` in `BeaconRootView`; the table is a `LazyVStack` within it.

### "Inline alert displayed within the input form" (PRD §F5)

Interpreted as "rendered inside `InputFormView`, just above the Calculate button" so it's always in the user's eyeline when they're about to tap. Could have been placed near the relevant field — rejected because alerts are conceptually about the form-as-a-whole (insufficient payment is a payment-vs-interest combination, not a payment-field issue).

### "Alternating row visual treatment" (PRD §F3)

Interpreted as edge-to-edge alternating backgrounds (full-bleed) rather than within-content alternation. Edge-to-edge is the standard finance-app look (Apple Stocks, Wallet, banking apps). The within-content alternative would have made the table feel like a card list — different visual register.

### "Final row clearly indicates $0.00 remaining balance" (PRD §F3)

Interpreted as `.beaconAccentTint` background per usage guide rule #2 ("$0 final amortization row" listed under sage's progress semantics). The visible row otherwise looks like any other row — same fonts, same column widths — but the sage tint marks it as "this is the moment your debt is gone." Final-row tint takes priority over alternation when both apply.

### Page title text: "Beacon"

Tech spec §3.2 hierarchy shows no explicit page title. Usage guide gives `.beaconPageTitle` example as "Your payoff plan." The previous `BeaconRootView` placeholder used `Text("Beacon")`. Kept "Beacon" since it was already there and the brand-forward title fits better for a single-screen app than a content-descriptive title. Easy to revisit in design polish.

---

## Known issues

### Catastrophic byMonths case — RESOLVED in Phase 2.2

The `KNOWN_ISSUES.md` "Calculator: byMonths mode payment derivation gap" was downgraded from Medium to Low after Phase 2.2 added the validator-layer catch. The catastrophic case (empty-plan return) is no longer reachable through the UI — `InputValidator.byMonthsFeasibilityError` surfaces a months-field error before the calculator runs.

The short-term ±1 row drift remains as accepted v1 behavior. See `KNOWN_ISSUES.md` for the full resolution write-up.

### No new known issues introduced in Phase 2

The Phase 2 build did not introduce any new bugs that warrant tracking in `KNOWN_ISSUES.md`. The closest items are:

* **Currency-cell minimum-scale at large balances:** on smaller iPhones with very large balances (e.g., $50K+), currency columns may shrink via `.minimumScaleFactor(0.7)`. Visual is acceptable but not ideal. Phase 4 polish could revisit (truncation patterns, column-width tuning, abbreviated formatting like "$50K"). Not promoted to `KNOWN_ISSUES.md` because the table still reads cleanly.
* **iPad screen margins:** `BeaconLayout.screenMarginLarge = 24` exists but isn't applied conditionally. iPad currently uses the iPhone value (16). The 600pt content cap centers the form/title/disclaimer on iPad correctly, so the visual is fine, just slightly tighter than ideal at the inner content edges. Phase 4.

---

## Deferred from Phase 2

These were considered and intentionally not implemented yet.

### `SummaryStatCard` / `SummaryRow`

Tech spec §3.2 places these above the table — total interest, payoff date, total months. Phase 3. Deferred because the table is the headline result; the summary stats are valuable but not required for the core loop to function.

### `PayoffChartView` and `ChartTooltipOverlay`

The high-risk item from tech spec §1.2. Phase 3. Deferred to keep Phase 2 focused on the input → table loop. The chart and the table are independent renderings of the same `PayoffPlan.rows`, so they can be added without touching anything in Phase 2.

### `RecalculateBar`

Sticky bar with scroll-to-top behavior. Phase 3. Deferred because it requires the sticky-bar pattern (`.safeAreaInset(edge: .top)` + `.regularMaterial`) and the scroll-to-top behavior, neither of which the core loop strictly needs in Phase 2.

The implementation note from the usage guide: this should use `BeaconMotion.appearance` for first-time slide-in (one of the three places that token fires).

### `StaleResultsNotice`

Inline notice that appears below the form and above the results when inputs are edited post-calculation. Phase 3, alongside `RecalculateBar`. Deferred because both belong to the post-first-calculation user flow, which the Phase 2 core loop doesn't formally support yet (the calculate button works on subsequent calculations, but the stale-data signaling is missing).

The implementation will use `InlineNotice` with the `.neutral` variant (already shipped in Phase 2.0).

### Two new design system tokens flagged in Phase 2.0

`Color.beaconOnAccent` (white text on sage fill) and `BeaconOpacity.disabled` (0.4). User confirmed "keep as-is" for v1. Candidates for tokenization in v1.x if they recur in components beyond `PrimaryButton`.

### iPad-conditional screen margins

`BeaconLayout.screenMarginLarge` exists but isn't applied. Phase 4 polish.

### UI tests

Phase 2 introduced significant UI but no UI tests. The `#Preview` blocks are for visual confirmation in Xcode canvas; they don't run as part of the test suite. Phase 4 or 5 if added at all.

---

## Test infrastructure notes for Phase 3+

### `InputValidatorTests.swift` is now its own file

Phase 1 anticipated this split: *"When test count grows past ~50 or when InputValidator gets its own dedicated test file, splitting into the proposed subfolders makes sense."* Phase 2.2 created `BeaconTests/InputValidatorTests.swift` as the first dedicated validator test file. Future validator-specific tests should go here rather than in `BeaconViewModelTests`.

The test file currently has one test (`test_byMonths_atCeilingWithHighAPR_surfacesMonthsFieldError`). Phase 3 may add more if the recalculate flow surfaces validator-specific concerns.

### Folder structure decision still deferred

The Phase 1 doc's note about splitting tests into `BeaconTests/Calculation/`, `BeaconTests/Validation/`, `BeaconTests/ViewModel/` subfolders is still deferred. Three test files at top level (`BeaconTests.swift` for calculator tests, `BeaconViewModelTests.swift`, `InputValidatorTests.swift`) is manageable. Revisit if test file count grows past five or six.

### Test count

Phase 1: 27 tests. Phase 2 added 1 (the validator catastrophic-case catch) → **28 tests total, all green**. The Phase 2 sub-phases that added UI did not add tests. The trade-off is intentional: SwiftUI view testing is high-overhead for marginal value at this stage; visual confirmation via `#Preview` and end-to-end testing in simulator catches most regressions. Phase 4 or 5 should make a deliberate call about UI test coverage.

### End-to-end manual ride-through

Phase 2.4 introduces the first opportunity to actually use Beacon end-to-end. The recommended sanity-check sequence (documented in the Phase 2.4 chat handoff) walks through: empty state → field validation → happy path byMonths → mode switch field-clearing → insufficient payment alert → byMonths catastrophic case → recalculation. All seven items pass on iPhone 15 Pro simulator at the time of this writing.

---

## What Phase 3 starts with

Per tech spec §7, Phase 3 is "Supporting Features" — the full v1 experience around the working core loop. Items in the recommended order:

### 1. `PayoffChartView` (HIGH RISK)

Tech spec §1.2 identifies SwiftUI Charts touch interaction as the highest-risk item in the project. The recommendation there: build and test the chart's tap-to-tooltip behavior in isolation **before** integrating into the full screen layout, referencing Apple's WWDC sample code for `.chartOverlay` coordinate-translation patterns.

Recommend honoring this. A standalone test harness view that renders a chart with mock `PayoffPlan` rows, gets the tap interaction working, then wires into the real screen.

### 2. `ChartTooltipOverlay`

The custom tooltip rendered when a user taps a chart point. Tech spec sizes this as a **L** item — the most complex single piece in Phase 3. Will use `InlineNotice`-style chrome but with custom positioning logic tied to the chart's coordinate space.

### 3. `RecalculateBar` and `StaleResultsNotice` together

Both belong to the post-first-calculation flow. The bar is a sticky `.safeAreaInset(edge: .top)` view; the notice is an `InlineNotice` with the `.neutral` variant placed below the form. The full flow: user successfully calculates → bar appears (BeaconMotion.appearance slide-in) → user edits an input → notice appears below form (BeaconMotion.appearance fade-in) → user taps Calculate → notice dismisses, results update in place.

### 4. `SummaryRow` / `SummaryStatCard`

Hero stats above the table — payoff date (`.beaconHeroNumber`, the one-per-screen hero number), total interest, total months. Custom-by-necessity per usage guide.

### 5. Smaller items

* `InlineAlertView` already exists from Phase 2 and is functional. Phase 3 may add a refinement (e.g., an explicit dismiss affordance, animation polish).
* Background/foreground state restoration is out of scope per the tech spec.

### What Phase 3 doesn't change

* The calculator stays the same. The validator stays the same.
* The input form stays the same. The amortization table stays the same.
* The `BeaconRootView` composition will gain insertions (chart between form and table; recalculate bar; stale notice) but the form/table from Phase 2.4 work as-is.
* The `AmortizationTableView` already accepts `[AmortizationRow]` — exactly what the chart will also consume. No data refactoring needed.

The ViewModel is fully ready for Phase 3. Every property the new components need (`plan?.rows` for the chart, `hasStaleResults` for the stale notice, `showRecalculateBar` for the bar) is already exposed.

---

## Files modified or created in Phase 2

```
Beacon/DesignSystem/Components/  ← all replaced from stubs
├── DisclaimerFooter.swift          ← created (Phase 2.0)
├── Field.swift                     ← created (Phase 2.0); revised mid-phase to take String? error
├── InlineNotice.swift              ← created (Phase 2.0)
├── MenuField.swift                 ← created (Phase 2.0)
└── PrimaryButton.swift             ← created (Phase 2.0)

Beacon/Features/PayoffPlanner/InputForm/  ← all replaced from stubs
├── APRField.swift                  ← created (Phase 2.1)
├── BalanceField.swift              ← created (Phase 2.1)
├── CalculateButton.swift           ← created (Phase 2.1)
├── InlineAlertView.swift           ← created (Phase 2.1)
├── InputFormView.swift             ← created (Phase 2.1)
├── MonthlyPaymentField.swift       ← created (Phase 2.1)
├── MonthsField.swift               ← created (Phase 2.1)
├── RepaymentModeSelector.swift     ← created (Phase 2.1)
└── StartDatePicker.swift           ← created (Phase 2.1)

Beacon/Features/PayoffPlanner/Results/   ← two of six stubs replaced
├── AmortizationRowView.swift       ← created (Phase 2.3); also defines AmortizationTableMetrics
└── AmortizationTableView.swift     ← created (Phase 2.3)

Beacon/App/
└── BeaconRootView.swift            ← replaced placeholder (Phase 2.4)

Beacon/Domain/Validation/
└── InputValidator.swift            ← extended (Phase 2.2)

BeaconTests/
└── InputValidatorTests.swift       ← created (Phase 2.2)

KNOWN_ISSUES.md                     ← updated (Phase 2.2)
Docs/beacon-results-from-phase-2.md ← this file
```

The remaining stubs in `Features/PayoffPlanner/Results/` (`PayoffChartView.swift`, `ChartTooltipOverlay.swift`, `ResultsView.swift`, `SummaryRow.swift`) and `Features/PayoffPlanner/Chrome/` (`RecalculateBar.swift`, `StaleResultsNotice.swift`) are awaiting Phase 3.

---

*Beacon Phase 2 results — captured at the boundary between core-loop and supporting-features work. Next session begins with the high-risk chart touch interaction, ideally in isolation before integration.*
