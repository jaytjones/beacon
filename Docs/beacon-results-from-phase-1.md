# Beacon — Phase 1 Results

**Phase:** 1 (Foundation)
**Date completed:** May 2026
**Reference docs:** `Docs/PRD.md`, `Docs/TechSpec.md`, `Docs/DesignSystemUsageGuide.md`

This document captures everything that was built, decided, or discovered during Phase 1 that **isn't** in the tech spec — so Phase 2 (and any future contributors) can pick up without re-deriving the context. The tech spec remains the source of truth for what was specified; this is the diff between specified and built.

---

## What's done

| Component | Path | Status |
|---|---|---|
| Domain models | `Beacon/Domain/Models/*.swift` | All six types from tech spec §2.2 |
| Calculation engine | `Beacon/Domain/Calculation/AmortizationCalculator.swift` | Pure Swift; Decimal throughout; 360-month ceiling enforced |
| Calculator tests | `BeaconTests/BeaconTests.swift` | 15 tests — happy paths, edge cases, date math, pinned known issues |
| Input validator | `Beacon/Domain/Validation/InputValidator.swift` | Field errors + business-logic alerts per PRD §7 |
| ViewModel | `Beacon/Features/PayoffPlanner/BeaconViewModel.swift` | `@MainActor`, reactive validation, stale-results tracking |
| ViewModel tests | `BeaconTests/BeaconViewModelTests.swift` | 12 tests — initial state, calculate flow, mode switching, alerts |

**27 tests total, all green.** No SwiftUI views beyond placeholder `BeaconRootView` exist yet.

---

## Architectural decisions made during the build

These were chosen during Phase 1 implementation, not specified upfront. Recording them so they're not silently re-litigated in Phase 2+.

### Decimal arithmetic style: direct, not wrapped

We considered two approaches: **(A)** use Swift's `Decimal` operators directly and drop into `NSDecimalRound` for rounding, or **(B)** wrap everything in a custom `Money` value type. Chose **A** for v1 — less abstraction, less code, and the rounding policy is enforced by a single helper (`AmortizationCalculator.round(_:scale:)`).

**Implication for v1.x:** if multi-card or multi-currency is added in v1.1+, that's the right time to introduce a `Money` wrapper. The calculator's rounding helper is the natural seam to refactor through.

### Calculator helper visibility: static, package-internal

`AmortizationCalculator.firstOfMonth`, `.daysInMonth`, `.round`, and `.maxMonths` are exposed as `static` (not `private`) so `InputValidator` can call them. Specifically:

- `InputValidator.firstMonthInterestEstimate` reuses the calculator's daily-rate × days-in-month formula so the insufficient-payment threshold matches what the engine would actually compute.
- `InputValidator` references `AmortizationCalculator.maxMonths` to enforce the 360-month ceiling at the field level.

This keeps the daily-rate interest formula in one place. If the tech spec ever wants to lock down calculator internals, these helpers should move to a shared `CalculationMath` namespace.

### `@MainActor` on the ViewModel

`BeaconViewModel` is annotated `@MainActor`. SwiftUI requires `@Published` mutations on the main thread, and the annotation enforces this at compile time. **Tests that touch the ViewModel must also be `@MainActor`** — `BeaconViewModelTests` is annotated accordingly.

### 50ms debounce on reactive validation

The Combine pipeline that drives revalidation debounces field changes by 50ms. Not specified in the tech spec — chosen to batch fast typing and paste events into a single validation pass without feeling laggy. Tunable.

**Implication for tests:** any test that asserts post-edit state must wait at least 100ms (`Task.sleep(nanoseconds: 100_000_000)`) for the debounce to settle. This is captured in the test file.

### `dropFirst()` on the validation publisher

The Combine pipeline calls `.dropFirst()` to skip the synchronous initial emission Combine fires on subscription. Without this, `revalidate()` would fire once during `init()`, populating empty-field errors before the user has typed anything — meaning the form would open with errors visible. We want the form to open clean, errors only after edits or calculate.

---

## Additions and extensions beyond the tech spec

These weren't wrong in the spec — they just weren't fully specified, and decisions had to be made.

### `InputValidator.RawInputs` nested struct

The tech spec defines `ValidationResult` and `FieldError` (§2.2) but doesn't specify the input contract for the validator itself. We introduced `InputValidator.RawInputs` as the value-type snapshot the validator consumes:

```swift
struct RawInputs: Equatable {
    var balance: String
    var apr: String
    var mode: RepaymentMode
    var months: String
    var monthlyPayment: String
    var startMonth: Int
    var startYear: Int
}
```

This keeps the validator stateless and testable in isolation. The ViewModel snapshots its current state into `RawInputs` whenever it calls `validate(_:)` or `buildInput(from:)`.

### `InputValidator.buildInput(from:)`

Companion to `validate(_:)`. Produces a `RepaymentInput?` from raw inputs that have already been validated. Returns `nil` if validation would fail — defensive contract not in the spec, but it makes the ViewModel's `calculate()` flow cleaner.

### `FieldError` Equatable override

The tech spec defines `FieldError` with `id = UUID()`. Auto-derived `Equatable` on a struct with a `UUID` ID makes every error unequal to every other (different UUIDs each instance), which makes tests painful. We added a custom `==` that compares on `(field, message)` and ignores `id`. **Side effect:** two `FieldError` values with the same field and message are now `==`, even if their UUIDs differ. This is what we want for tests, and it shouldn't matter at runtime since the UUIDs are never compared in production code.

### `ValidationResult.valid` static helper

Convenience static property: `static let valid = ValidationResult(isValid: true, fieldErrors: [], alertType: nil)`. Not in the spec, but it makes test assertions and "no errors yet" returns more readable.

### `parseDecimal` tolerates commas and `$` prefix

`InputValidator.parseDecimal` strips commas and a leading `$` before parsing. So `"$1,234.56"` becomes `1234.56`. The tech spec doesn't specify input formatting tolerance — this is a UX call. Worth a Phase 4 polish review to decide whether to also tolerate trailing whitespace patterns, parenthesized negatives (we don't allow negatives anyway), etc.

### Insufficient-payment minimum: `interest + $1`

The PRD says the alert message should suggest "at least $X" but doesn't specify the formula. We chose `firstMonthInterestEstimate + 1`, rounded to 2 decimal places. Adding the dollar guarantees the suggested payment will actually amortize (covers interest + at least $1 of principal). Reasonable but not authoritative — easy to tune if user testing suggests a different anchor (e.g., interest × 1.1, or interest + 5% of balance).

---

## Interpretations of ambiguous spec language

Where the spec was open to reading, here's how we read it.

### `termExceedsMax` for `byMonths` mode

The tech spec describes `termExceedsMax` as a runtime alert that fires when a payment in `.byPayment` mode would result in a term over 360 months. For `.byMonths` mode, the user enters the term directly — there's no projection involved. We treat `months > 360` as a **field-level error** (`"Please enter a repayment term of 360 months or fewer"`) rather than an alert.

Both fire from validation; the difference is purely UI placement: field errors render inline with the field, alerts render in `InlineAlertView` below the form. This matches the spec's split between field errors and alerts even though the spec didn't address the byMonths overflow case explicitly.

### "Returns `.termExceedsMax` gracefully"

Tech spec §5.4: *"If the engine is ever called with invalid input, it returns a `.termExceedsMax` gracefully rather than hanging."* We interpret "gracefully" as **returning a `PayoffPlan` with an empty `rows` array**. The calculator doesn't produce an `AlertType` itself (those are validation-layer concerns) — but it does have a clear "I bailed out" signal: empty rows. Tests pin this with `test_termBeyond360_returnsEmptyPlan` and `test_byMonths_atCeilingWithHighAPR_returnsEmptyPlan`.

If a future iteration wants the calculator to surface *why* it bailed, the cleanest move is to change the return type to `Result<PayoffPlan, CalculatorError>`. Not needed for v1.

### Calculation runs synchronously on `@MainActor`

PRD requires <1 second for any term up to 360 months. The calculator is a pure function, no I/O. We run it synchronously on the main thread. **If profiling on older devices (Phase 5) shows the 360-row case approaches the 1-second budget**, the fix is to wrap the call in `Task.detached` and `await` the result. The ViewModel's `isCalculating` flag is already there to drive the spinner.

---

## Known issues

### Calculator: `byMonths` derivation gap (also in `KNOWN_ISSUES.md`)

`AmortizationCalculator.derivedMonthlyPayment` uses the monthly rate approximation `APR / 12`, while per-row interest uses the daily rate `APR / 365 × daysInMonth`. For 31-day months at high APRs, the daily-rate equivalent (`31/365 × APR ≈ APR × 1.0193 / 12`) is slightly higher than `APR / 12`.

At long terms with high APRs (e.g., 18% / 360 months) and 31-day starting months, the derived payment can fall below the first-month interest charge. The engine hits the `monthNumber > 360` safety valve and returns an empty plan rather than amortizing.

**Reproduces:** `RepaymentInput(balance: 10000, apr: 18, mode: .byMonths, months: 360, startMonth: 1, ...)` returns a `PayoffPlan` with empty rows.

**Pinned by:** `AmortizationCalculatorTests.test_byMonths_atCeilingWithHighAPR_returnsEmptyPlan`.

**Recommended fix path:** validation-layer catch — `InputValidator` should detect this case and surface it as a field error or alert before reaching the engine. This is consistent with the spec's design (engine assumes valid input; alerts fire upstream). Other options (bumping the derived payment, switching to a daily-rate-equivalent monthly rate) are documented in `KNOWN_ISSUES.md` but rejected as more invasive.

**Severity:** Medium. Affects a UI-pathological case (a 30-year credit card payoff is itself a strategic mistake worth flagging in the UI), but the math drift is real and the empty-plan return is a worse user experience than a clear error message.

---

## Deferred from Phase 1

These were considered and intentionally not implemented yet.

### APR ≤ 1.0 "decimal vs percentage" warning

Tech spec §6.1 specifies: *"User enters 0.24 (decimal) instead of 24 → if value ≤ 1.0, surface warning."* The PRD §7 error states table doesn't include this case (it relies on placeholder text to prevent it).

Current state: **not implemented.** Adding it now would lock in a decision (warning vs hard error vs soft hint) before the design system has a treatment for "soft warnings" — there's no UI pattern for this in the design system yet. Easy to bolt on in Phase 4 polish once the warning UX is decided.

### `Money` value type

See "Decimal arithmetic style" above. Right call to defer until v1.1 multi-card/multi-currency forces the issue.

### Detailed `CalculatorError` return type

See "Returns `.termExceedsMax` gracefully" above. Empty-rows is sufficient for v1.

---

## Test infrastructure notes for Phase 2+

### Test file layout

The original project structure proposal had `BeaconTests/Calculation/`, `BeaconTests/Validation/`, and `BeaconTests/ViewModel/` subfolders. **We didn't create the subfolders yet** — both test files (`AmortizationCalculatorTests.swift` and `BeaconViewModelTests.swift`) sit at the top of `BeaconTests/`. When test count grows past ~50 or when `InputValidator` gets its own dedicated test file, splitting into the proposed subfolders makes sense.

### Decimal comparison helper

Test code can't use Swift's generic `abs()` on `Decimal` directly (Decimal doesn't conform to `Comparable` in the way `abs` requires). Tests use a local helper:

```swift
private func absDouble(_ value: Decimal) -> Double {
    let positive = value < 0 ? -value : value
    return NSDecimalNumber(decimal: positive).doubleValue
}
```

…for "within $0.01" tolerance comparisons. **If you write a new test with a tolerance assertion, use this pattern**, not `abs(_:)`.

### Input builders in tests

`AmortizationCalculatorTests` defines two helpers (`payment(...)` and `months(...)`) that build `RepaymentInput` with sensible defaults. New calculator tests should use these for readability.

### Debounce tolerance in async tests

Any ViewModel test that asserts post-edit state needs `try? await Task.sleep(nanoseconds: 100_000_000)` (100ms) to let the 50ms debounce settle. The 100ms gives 2× headroom.

---

## What Phase 2 starts with

Per tech spec §7 ("Build Order"), Phase 2 is the "Core Loop" — the minimum that demonstrates Beacon's value end-to-end:

1. **`InputFormView`** — all fields, mode toggle, date pickers, bound to the existing ViewModel
2. **Field validation rendering** — wiring `viewModel.error(for:)` into each field's inline error display
3. **`CalculateButton`** — taps `viewModel.calculate()`; shows spinner; disabled when `!canCalculate`
4. **`AmortizationTableView`** — `LazyVStack` rendering of `viewModel.plan?.rows`
5. **End-to-end manual test** — enter real inputs in the simulator, see the correct table

The ViewModel is fully ready for Phase 2. Every property and method Phase 2 views need is already there:

| View needs… | ViewModel provides |
|---|---|
| Two-way bind text fields | `$balanceText`, `$aprText`, `$monthsText`, `$monthlyPaymentText` |
| Two-way bind start date | `$startMonth`, `$startYear` |
| Two-way bind mode toggle | `$repaymentMode` (or call `switchMode(to:)` for the clear-inactive-field side effect) |
| Render inline field error | `error(for: .balance)`, etc. |
| Render alert | `alertType` |
| Disable Calculate button | `!canCalculate` |
| Show spinner | `isCalculating` |
| Show stale notice | `hasStaleResults` |
| Show results | `plan != nil`, `showResults` |
| Show recalculate bar | `showRecalculateBar` |
| Trigger calculate | `calculate()` |

**Before any Phase 2 view is built**, the design system components it depends on (`Field`, `PrimaryButton`, `MenuField`, `InlineNotice`) need to exist. Those are placeholder files right now. The cleanest sequencing is: design system components first (lower-level, no ViewModel dependency), then `InputFormView` and friends.

---

## Files modified or created in Phase 1

```
Beacon/Domain/Models/
├── RepaymentMode.swift        ← implemented
├── RepaymentInput.swift       ← implemented
├── AmortizationRow.swift      ← implemented
├── PayoffPlan.swift           ← implemented
├── AlertType.swift            ← implemented
└── ValidationResult.swift     ← implemented (also defines InputField, FieldError)

Beacon/Domain/Calculation/
└── AmortizationCalculator.swift   ← implemented

Beacon/Domain/Validation/
└── InputValidator.swift           ← implemented

Beacon/Features/PayoffPlanner/
└── BeaconViewModel.swift          ← implemented

BeaconTests/
├── BeaconTests.swift              ← replaced default with AmortizationCalculatorTests
└── BeaconViewModelTests.swift     ← created

KNOWN_ISSUES.md                    ← created at repo root
Docs/beacon-results-from-phase-1.md ← this file
```

All other files in the scaffold remain placeholders awaiting Phase 2+.

---

*Beacon Phase 1 results — captured at the boundary between foundation and core-loop work. Next session begins with design system components, then `InputFormView`.*
