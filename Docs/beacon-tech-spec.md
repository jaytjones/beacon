# Beacon — Technical Specification

**Version 1.0 | May 2026**
*Derived from Beacon PRD v1.0 using the Tech Spec Prompts Guide*

---

## Table of Contents

1. [Tech Stack](#1-tech-stack)
2. [Data Models](#2-data-models)
3. [Screens & Component Breakdown](#3-screens--component-breakdown)
4. [State Management](#4-state-management)
5. [Calculation Engine](#5-calculation-engine)
6. [Error Handling & Edge Cases](#6-error-handling--edge-cases)
7. [Build Order](#7-build-order)
8. [Open Questions](#8-open-questions)

---

## 1. Tech Stack

### 1.1 Decisions

| Layer | Decision | Rationale |
|---|---|---|
| **Language** | Swift 5.9+ | Native iOS; no alternative |
| **UI Framework** | SwiftUI | PRD-specified; enables Charts framework; modern declarative UI |
| **Architecture** | MVVM | Standard SwiftUI pattern; clean separation of calculation logic from view layer |
| **Charts** | SwiftUI Charts (iOS 16+) | PRD-specified; native; supports `.chartOverlay` for tap interaction |
| **State management** | `@StateObject` / `@ObservedObject` | No cross-screen sharing needed; no third-party library required |
| **Persistence** | None | All data is session-only per PRD |
| **Authentication** | None | Not required in v1 |
| **Backend / API** | None | All calculations run client-side; no data transmitted |
| **Database** | None | No persistence in v1 |
| **Minimum iOS** | iOS 16 | Required for SwiftUI Charts |
| **Distribution** | Apple App Store | PRD-specified |
| **External APIs** | None | No third-party integrations in v1 |

### 1.2 Tech Risks

**Risk 1 — SwiftUI Charts touch interaction (HIGH)**
- What could go wrong: `.chartOverlay` for tap-to-tooltip is finicky; coordinate mapping from gesture to data point is manual and error-prone, especially on non-linear axis scales.
- Mitigation: Build and test the chart touch interaction in isolation in Phase 1 before integrating it into the full screen layout. Reference Apple's WWDC sample code for `.chartOverlay` coordinate translation patterns.

**Risk 2 — Decimal precision in financial calculations (HIGH)**
- What could go wrong: `Double` floating-point arithmetic produces rounding errors that compound across 360 months; a $0.01 drift per row becomes visually and functionally wrong by month 50.
- Mitigation: Use `Decimal` (not `Double` or `Float`) for all financial arithmetic throughout the calculation engine. Round to 2 decimal places only at display time and at the final-month adjustment. Unit-test against known amortization outputs.

**Risk 3 — 360-row table performance on older iPhones (MEDIUM)**
- What could go wrong: Rendering 360 rows in a SwiftUI `List` or `ScrollView` can cause janky scrolling on older A-series chips if each row is over-architected.
- Mitigation: Use `LazyVStack` inside a `ScrollView` (not `List`) so rows are only instantiated as they scroll into view. Keep each row view lightweight — no computed properties in the body. Profile on iPhone XR (A12) in Instruments before shipping.

---

## 2. Data Models

### 2.1 Logical Entities

**RepaymentMode**
Enum — represents the two input modes for the repayment form.

**RepaymentInput**
The user's form input at the time a calculation is run. Fields: balance (Decimal, required), apr (Decimal, required, 0–100), mode (RepaymentMode, required), months (Int?, required when mode is `.byMonths`), monthlyPayment (Decimal?, required when mode is `.byPayment`), startMonth (Int, 1–12, defaults to current month), startYear (Int, defaults to current year).

**AmortizationRow**
One row of the amortization table — one calendar month in the payoff plan. Fields: monthNumber (Int, 1-based index), date (the first day of that calendar month), payment (Decimal — the amount paid this month), interestPaid (Decimal), principalPaid (Decimal), remainingBalance (Decimal — 0.00 in the final row).

**PayoffPlan**
The complete output of a calculation run. Fields: input (RepaymentInput — snapshot of inputs used), rows ([AmortizationRow]), totalInterestPaid (Decimal — sum of interestPaid across all rows), totalAmountPaid (Decimal — sum of payment across all rows), payoffDate (Date — date of the final row).

**ValidationResult**
The result of validating a RepaymentInput. Fields: isValid (Bool), fieldErrors ([FieldError] — per-field inline messages), alertType (AlertType? — `.insufficientPayment(minimum: Decimal)` or `.termExceedsMax`).

### 2.2 Swift Type Definitions

```swift
// MARK: - Enums

enum RepaymentMode: String, CaseIterable {
    case byMonths      = "By months"
    case byPayment     = "By payment amount"
}

/// Distinguishes the two inline alert conditions
enum AlertType: Equatable {
    case insufficientPayment(minimum: Decimal)
    case termExceedsMax
}

// MARK: - Input & Output

/// Snapshot of validated user input — passed to the calculation engine
struct RepaymentInput: Equatable {
    let balance: Decimal
    let apr: Decimal            // stored as percentage, e.g. 24.99 for 24.99%
    let mode: RepaymentMode
    let months: Int?            // non-nil when mode == .byMonths
    let monthlyPayment: Decimal? // non-nil when mode == .byPayment
    let startMonth: Int         // 1–12
    let startYear: Int
}

/// One row of the amortization table
struct AmortizationRow: Identifiable {
    let id: Int                 // == monthNumber
    let monthNumber: Int        // 1-based
    let date: Date              // first of the calendar month
    let payment: Decimal
    let interestPaid: Decimal
    let principalPaid: Decimal
    let remainingBalance: Decimal
}

/// Complete output of a calculation run
struct PayoffPlan {
    let input: RepaymentInput
    let rows: [AmortizationRow]
    let totalInterestPaid: Decimal
    let totalAmountPaid: Decimal
    let payoffDate: Date
}

// MARK: - Validation

struct FieldError: Identifiable, Equatable {
    let id = UUID()
    let field: InputField
    let message: String
}

enum InputField {
    case balance, apr, months, monthlyPayment
}

struct ValidationResult {
    let isValid: Bool
    let fieldErrors: [FieldError]
    let alertType: AlertType?
}
```

### 2.3 No Database Schema Required

All data is ephemeral and session-scoped. No persistence layer, no Core Data, no UserDefaults for financial data. The only candidate for UserDefaults in v1.1 would be user preferences (e.g., last-used repayment mode) — no financial values.

---

## 3. Screens & Component Breakdown

### 3.1 Route Table

Beacon is a single-screen app. There are no navigation routes. All state is managed within one root view.

| View | Description | Auth Required | Data Loaded On |
|---|---|---|---|
| `BeaconRootView` | Root container; owns the ViewModel | No | App launch |

No modals, drawers, or sheet presentations are required in v1. Alerts are inline, not system `Alert` dialogs.

### 3.2 Component Hierarchy

```
BeaconRootView
├── RecalculateBar              [sticky, shown after first calc]
└── ScrollView (main)
    ├── InputFormView
    │   ├── BalanceField
    │   ├── APRField
    │   ├── RepaymentModeToggle (pill toggle)
    │   ├── MonthsField         [shown when mode == .byMonths]
    │   ├── MonthlyPaymentField [shown when mode == .byPayment]
    │   ├── StartDatePicker
    │   │   ├── MonthDropdown
    │   │   └── YearDropdown
    │   ├── InlineAlertView     [shown on alert condition]
    │   ├── CalculateButton
    │   └── StaleResultsNotice  [shown when inputs changed post-calc]
    └── ResultsView             [hidden until first successful calc]
        ├── SummaryRow          [total interest, payoff date, months]
        ├── PayoffChartView
        │   └── ChartTooltipView [conditionally shown on tap]
        └── AmortizationTableView
            └── AmortizationRowView × N
```

### 3.3 Component Detail

**RecalculateBar**
- Reused across states: No (unique to app chrome)
- Local state: None
- Props from parent: `isVisible: Bool`, `onTap: () -> Void`
- Interactions: Tap → scroll to top of InputFormView

**InputFormView**
- Reused: No
- Local state: None — all form state lives in the ViewModel
- Props: `viewModel: BeaconViewModel` (observed)
- Interactions: All field edits, toggle changes, date picker changes, calculate tap

**RepaymentModeToggle**
- Reused: No
- Local state: None (mode is in ViewModel)
- Interactions: Tap switches active mode, resets the inactive field's value and any validation error on it

**InlineAlertView**
- Reused: Yes — used for both `insufficientPayment` and `termExceedsMax` alerts
- Props: `alertType: AlertType`, `minimumPayment: Decimal?`
- Interactions: None (informational only)

**CalculateButton**
- Disabled state when: any required field is empty, any field error exists, or alert condition is active
- Local state: None (enabled state derived from ViewModel)

**PayoffChartView**
- Reused: No
- Local state: `selectedRow: AmortizationRow?` (tooltip visibility)
- Props: `rows: [AmortizationRow]`
- Interactions: Tap on chart → set `selectedRow`; tap elsewhere → clear

**AmortizationTableView**
- Reused: No
- Props: `rows: [AmortizationRow]`
- Uses `LazyVStack` inside a nested `ScrollView` (independent scroll)
- Interactions: Scroll only

**AmortizationRowView**
- Reused: Yes (one per row)
- Props: `row: AmortizationRow`, `isAlternate: Bool`
- Interactions: None

---

## 4. State Management

### 4.1 State Categories

**No server state.** All data is computed locally.

**Global client state — `BeaconViewModel` (@StateObject, owned by BeaconRootView)**

```swift
class BeaconViewModel: ObservableObject {

    // Form inputs (bind directly to fields)
    @Published var balanceText: String = ""
    @Published var aprText: String = ""
    @Published var repaymentMode: RepaymentMode = .byMonths
    @Published var monthsText: String = ""
    @Published var monthlyPaymentText: String = ""
    @Published var startMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var startYear: Int = Calendar.current.component(.year, from: Date())

    // Computation state
    @Published var plan: PayoffPlan? = nil          // nil until first successful calc
    @Published var isCalculating: Bool = false
    @Published var hasStaleResults: Bool = false    // true when inputs edited post-calc

    // Validation
    @Published var fieldErrors: [FieldError] = []
    @Published var alertType: AlertType? = nil

    // Derived
    var canCalculate: Bool { fieldErrors.isEmpty && alertType == nil && hasRequiredFields }
    var showResults: Bool { plan != nil }
    var showRecalculateBar: Bool { plan != nil }
}
```

**Local component state**

| Component | State | Type |
|---|---|---|
| `PayoffChartView` | `selectedRow` | `AmortizationRow?` |

**URL state** — None (native app; no URL routing).

**Form state** — Lives in ViewModel as `@Published` String properties bound via `TextField`. Parsed to `Decimal`/`Int` on validation.

### 4.2 Validation Trigger Strategy

Validation runs reactively using Combine's `.sink` on the ViewModel's published properties — not on every keystroke, but on `calculate()` invocation and on mode switches. Field-level format errors (non-numeric) surface immediately on field change. Business-logic errors (insufficient payment, term overflow) surface on calculate tap or live as the user types in the payment field.

```swift
// Pseudocode — validation is synchronous and returns a ValidationResult
func validate() -> ValidationResult {
    var errors: [FieldError] = []
    // 1. Parse and range-check each field
    // 2. Check payment vs. first-month interest
    // 3. If mode == .byPayment, project term; check if > 360
    return ValidationResult(isValid: errors.isEmpty, fieldErrors: errors, alertType: ...)
}
```

---

## 5. Calculation Engine

### 5.1 Overview

The calculation engine is a pure Swift struct with no dependencies on SwiftUI. It takes a validated `RepaymentInput` and returns a `PayoffPlan`. It should be unit-tested independently of the UI.

```swift
struct AmortizationCalculator {
    static func calculate(input: RepaymentInput) -> PayoffPlan { ... }
}
```

### 5.2 Calculation Logic

**Daily periodic rate:**
```
dailyRate = apr / 100 / 365
```

**Monthly interest charge (actual days in month):**
```
monthlyInterest = round(dailyRate × daysInMonth × currentBalance, 2)
```

**Principal paid:**
```
principalPaid = monthlyPayment − monthlyInterest
```

**Remaining balance:**
```
remainingBalance = previousBalance − principalPaid
```

**Final month adjustment:**
When `remainingBalance` would go below zero, the final payment is set to the exact remaining balance plus the final month's interest. This produces exactly $0.00 remaining — no overpayment.

**Mode: By months → derive monthly payment:**
```
// Standard amortization payment formula using Decimal arithmetic
// If APR == 0%, payment = balance / months (simple division)
// Otherwise: P × (r(1+r)^n) / ((1+r)^n − 1)
// where r = monthly rate approximation = apr / 100 / 12
```

Note: The PRD specifies daily rate for *interest calculation* per row. The monthly payment derivation from a target number of months uses the standard monthly rate approximation (`APR / 12`) to produce the payment amount, which is then used row-by-row with the precise daily-rate interest formula.

**APR = 0% special case:**
`monthlyInterest = 0` for all rows. `payment = balance / months`. No division-by-zero risk.

### 5.3 Date Calculation

The engine advances the calendar month-by-month from the user's selected start month/year using `Calendar.current`. `daysInMonth` is derived from `Calendar.current.range(of: .day, in: .month, for: date)!.count`.

### 5.4 Validation for Calculation Preconditions

Before running the engine, the ViewModel validates:

| Condition | Alert type |
|---|---|
| Monthly payment ≤ first month's interest charge | `.insufficientPayment(minimum:)` |
| Projected term > 360 months | `.termExceedsMax` |

The engine itself should `assert` these conditions are not met (they are caught upstream). If the engine is ever called with invalid input, it returns a `.termExceedsMax` gracefully rather than hanging.

### 5.5 Rounding Policy

- Use `Decimal` throughout all arithmetic
- `NSDecimalNumberHandler` with `.roundPlain`, scale 2 for display-ready values
- Never round intermediate values — only round `interestPaid` and `remainingBalance` per row to prevent compounding drift
- Final month: `payment = remainingBalance + finalMonthInterest`, then set `remainingBalance = 0.00` exactly

---

## 6. Error Handling & Edge Cases

### 6.1 Edge Case Map

| Screen | Action | Edge Case | Handling Strategy |
|---|---|---|---|
| Input form | Enter balance | $0 or blank | Inline error: *"Please enter a balance greater than $0"* |
| Input form | Enter balance | Non-numeric | Inline error: *"Please enter a valid dollar amount"* |
| Input form | Enter APR | Blank | Inline error: *"Please enter your APR"* |
| Input form | Enter APR | 0% | Valid — engine handles; no error |
| Input form | Enter APR | > 100% | Inline error: *"Please enter a valid APR — most credit cards are between 15% and 30%"* |
| Input form | Enter APR | User enters 0.24 (decimal) instead of 24 | Inline placeholder *"e.g. 24.99 for 24.99% APR"* prevents this; if value ≤ 1.0, surface warning |
| Input form | Enter months | 0 or negative | Inline error: *"Please enter a repayment term of at least 1 month"* |
| Input form | Enter months | Blank | Inline error: *"Please enter a number of months"* |
| Input form | Enter payment | ≤ first-month interest | Inline alert: *"Your payment doesn't cover the monthly interest. Try increasing it to at least $X."* |
| Input form | Enter payment | Results in term > 360 months | Inline alert: *"At this payment amount, your balance won't be paid off within 30 years."* |
| Input form | Switch mode mid-entry | Toggle while fields populated | Clear the inactive field value and its validation error; recalculate validation |
| Calculate | Tap button | Fields valid | Calculation runs; spinner shown; result renders |
| Calculate | Tap button | Button disabled | No-op (button is disabled) |
| Calculate | Floating-point drift | 359 rows in | Use `Decimal`; see rounding policy in §5.5 |
| Results | Amortization table | 1–3 month term | Table renders; only 1–3 rows shown; no empty padding |
| Results | Amortization table | 360-month term | LazyVStack renders incrementally; no perf degradation |
| Chart | Render | 1–3 month term | Adequate point spacing; axes auto-scaled |
| Chart | Render | Very small balance (e.g. $500) | Y-axis minimum is 0, max is balance; scale stays readable |
| Chart | Render | Very large balance (e.g. $50,000) | Y-axis formats as $50K or $50,000 (abbreviated for space) |
| Chart | Render | High APR + low payment → near-flat curve | Line still drawn; scale reflects reality; no artificial minimum slope |
| Chart | Tap | Tooltip shown | Tap elsewhere → dismiss |
| Recalculate | Edit fields post-calc | Any field changed | Stale notice appears; previous results remain until new calc runs |
| Recalculate | Edit fields post-calc | New input creates error | Error shown inline; notice stays; previous results persist |
| Recalculate | Edit fields post-calc | New input is valid | Tap Calculate → results update in place; notice dismisses |

### 6.2 Accessibility Requirements

- All error and alert states communicate via icon + text — never color alone
- Minimum tap targets per iOS HIG (44pt × 44pt)
- All interactive elements have `accessibilityLabel` and `accessibilityHint`
- Amortization table rows have structured `accessibilityLabel` reading: "Month N, [month name year], payment [amount], interest [amount], principal [amount], balance [amount]"
- Chart has `accessibilityLabel` summarizing the payoff plan; individual data points accessible via SwiftUI Charts' built-in accessibility support (series label + value)
- Legal disclaimer in footer has `accessibilityLabel`

---

## 7. Build Order

### Phase 1 — Foundation *(can't build anything without this)*

| Item | Description | Size | Blocks |
|---|---|---|---|
| Project setup | Xcode project, folder structure, SwiftLint config, Git | S | Everything |
| Data types | All Swift types from §2.2 | S | Engine, ViewModel |
| Calculation engine | `AmortizationCalculator` with full logic including edge cases | M | ViewModel, UI |
| Engine unit tests | Known amortization outputs; edge cases (0% APR, final-month adjustment, 360-month ceiling) | M | — |
| ViewModel skeleton | `BeaconViewModel` with all `@Published` properties; validation logic | M | All views |

### Phase 2 — Core Loop *(minimum that demonstrates Beacon's value)*

| Item | Description | Size | Blocks |
|---|---|---|---|
| InputFormView | All fields, mode toggle, date pickers; bound to ViewModel | M | — |
| Field validation | Inline field errors; calculate button enable/disable logic | M | — |
| CalculateButton + spinner | Taps ViewModel; shows spinner | S | — |
| AmortizationTableView | LazyVStack rendering; all columns; alternating rows | M | — |
| End-to-end test | Enter real inputs → see correct table | S | — |

### Phase 3 — Supporting Features *(full v1 experience)*

| Item | Description | Size | Blocks |
|---|---|---|---|
| PayoffChartView | SwiftUI Charts line graph; axes; dynamic scale | M | Tooltip |
| Chart tooltip | `.chartOverlay` tap gesture; coordinate mapping; tooltip dismiss | L | — |
| InlineAlertView | Insufficient payment alert; term-too-long alert | S | — |
| RecalculateBar | Sticky bar; scroll-to-top behavior | S | — |
| Stale results notice | Appears on post-calc field edit; dismisses on recalc | S | — |
| SummaryRow | Total interest, payoff date, total months above the table | S | — |

### Phase 4 — Polish

| Item | Description | Size | Blocks |
|---|---|---|---|
| All error states | Every inline error message wired and tested | M | — |
| All empty states | First-load state; no results visible | S | — |
| Loading states | Spinner on Calculate and Recalculate; resolves < 1 second | S | — |
| iPad scaling | Same layout scaled to iPad screen sizes | S | — |
| Accessibility pass | All labels, hints, tap targets; VoiceOver walkthrough | M | — |
| Legal disclaimer footer | Static text; correct `accessibilityLabel` | S | — |

### Phase 5 — Pre-Launch

| Item | Description | Size | Blocks |
|---|---|---|---|
| Performance profiling | Instruments on iPhone XR; 360-row table; chart render | M | — |
| App Store assets | Screenshots (6.7", 6.1", iPad), App Store description, keywords, icon | L | — |
| TestFlight build | Internal testing; install on physical devices | S | — |
| Final QA pass | All edge cases from §6.1 manually tested on device | M | — |

---

## 8. Open Questions

No open questions at time of spec publication. All PRD open questions were resolved in the PRD process. The following architectural decisions were made during spec creation and are recorded here for reference:

| Decision | Resolution |
|---|---|
| Decimal vs Double for financial math | **Decimal** throughout the calculation engine |
| Table rendering strategy | **LazyVStack** inside ScrollView (not SwiftUI List) |
| Month advance strategy | **Calendar.current** date math (handles leap years, varying month lengths) |
| Monthly payment derivation (By months mode) | **Standard amortization formula** using `APR / 12` as the monthly rate; daily rate used only for per-row interest calculation |
| Tooltip dismiss behavior | **Tap anywhere on chart** outside the active point dismisses |
| ViewModel ownership | **Owned by BeaconRootView** as `@StateObject`; passed to subviews as `@ObservedObject` |
| v1.1 architecture consideration (PDF export) | Ensure `PayoffPlan` is serializable and `AmortizationRow` values are fully computed at calculation time — not lazy — so export in v1.1 requires no recalculation |

---

*Beacon Tech Spec v1.0 — Built using the Tech Spec Prompts Guide (jaytjones/app-building-tools). Ready for build.*
