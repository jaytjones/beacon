# Beacon — Phase 4 Results

**Phase:** 4 (Polish & Launch Prep)
**Date completed:** May 2026
**Reference docs:** `Docs/beacon-prd.md`, `Docs/beacon-tech-spec.md`, `Docs/beacon-usage-guide.md`, `Docs/beacon-results-from-phase-1.md`, `Docs/beacon-results-from-phase-2.md`, `Docs/beacon-results-from-phase-3.md`

This document captures everything built, decided, or discovered during Phase 4 that **isn't** in the tech spec — so any future contributors or a v1.1 session can pick up without re-deriving context. The tech spec remains the source of truth for what was specified; this is the diff.

Phase 4 broke into seven chunks:

* **4.1** — End-to-end manual ride-through (primary validation pass + bug discovery)
* **4.2** — Disclaimer footer & legal copy verification
* **4.3** — Accessibility pass
* **4.4** — Performance profiling
* **4.5** — Error state completeness check
* **4.6** — iPad scaling check
* **4.7** — App Store prep (deferred — no Apple Developer subscription)

---

## What's done

| Chunk | Status | Notes |
|---|---|---|
| 4.1 End-to-end ride-through | ✅ Complete | Two bugs found and fixed (see below) |
| 4.2 Disclaimer footer | ✅ Complete | Visible and correct on all simulator sizes |
| 4.3 Accessibility pass | ✅ Complete | VoiceOver walkthrough passed |
| 4.4 Performance profiling | ✅ Complete | 360-row scroll smooth; calculation under 1 second |
| 4.5 Error state completeness | ✅ Complete | All 10 error cases verified |
| 4.6 iPad scaling check | ✅ Complete | Functional; known cosmetic gap noted (see below) |
| 4.7 App Store prep | ⏸ Deferred | Requires Apple Developer account ($99/year) |

**28 tests total, all green** (unchanged from Phase 3 — Phase 4 did not introduce new unit tests; all validation was manual).

---

## Bugs found and fixed during Phase 4

### Bug 1 — Summary stats displayed zeroed-out values for near-catastrophic inputs

**Discovered in:** Chunk 4.1 ride-through

**Symptoms:**
- Balance $5,000 / APR 99% / payment $407 (byPayment mode) → summary showed "0 mo / Jun 2026 / $0.00"
- Balance $5,000 / APR 5.99% / payment $25 (byPayment mode) → same zeroed-out output
- No error or alert was shown in either case; Calculate button was enabled and appeared to succeed

**Root cause — two separate gaps:**

*Gap 1 (APR 99%, $407):* The existing insufficient payment check only validated against the first month's interest. June has 30 days; first-month interest ≈ $406.85; payment of $407 passed the check correctly. However, July has 31 days, making that month's interest ≈ $420 — exceeding the $407 payment. The balance began growing rather than shrinking. The calculator looped until its `monthNumber > maxMonths` safety valve and returned a `PayoffPlan` with empty rows. The ViewModel then set `plan` to that empty plan, and `SummaryRow` displayed zeroes.

*Gap 2 (APR 5.99%, $25):* Payment of $25 cleared the first-month interest check (first-month interest ≈ $24.62). However, the projected term exceeded 360 months. No `termExceedsMax` check existed for byPayment mode — the validator only projected the term for byMonths mode. The calculator hit the same safety valve and returned an empty plan.

**Fixes applied:**

*Fix A — Defensive guard in `BeaconViewModel.calculate()`*

After the calculator returns, a guard now checks for an empty rows array before updating `plan`. If the calculator returns empty rows despite validation passing, `alertType` is set to `.termExceedsMax` and `plan` is not updated. This prevents the summary stats from ever displaying zeroed-out values regardless of any future validator gaps.

```swift
let result = AmortizationCalculator.calculate(input: input)

guard !result.rows.isEmpty else {
    self.alertType = .termExceedsMax
    return
}

self.plan = result
```

*Fix B — `byPaymentTermAlert` in `InputValidator`*

A new private helper was added to `InputValidator` that projects the full byPayment term using the same daily-rate math as the engine. It loops month-by-month (bounded at 360 iterations) and returns `.termExceedsMax` if either the term exceeds 360 months or the payment stops covering interest in any month:

```swift
private static func byPaymentTermAlert(
    balance: Decimal,
    apr: Decimal,
    payment: Decimal,
    startMonth: Int,
    startYear: Int
) -> AlertType? {
    let dailyRate = apr / 100 / 365
    var currentBalance = balance
    var monthNumber = 0
    var date = AmortizationCalculator.firstOfMonth(month: startMonth, year: startYear)
    let calendar = Calendar.current

    while currentBalance > 0 {
        monthNumber += 1
        if monthNumber > AmortizationCalculator.maxMonths {
            return .termExceedsMax
        }
        let days = AmortizationCalculator.daysInMonth(date)
        let interest = AmortizationCalculator.round(
            dailyRate * Decimal(days) * currentBalance, scale: 2
        )
        let principal = payment - interest
        if principal <= 0 {
            return .termExceedsMax
        }
        currentBalance -= principal
        date = calendar.date(byAdding: .month, value: 1, to: date) ?? date
    }
    return nil
}
```

The existing `case .byPayment:` alert block was updated to call this helper as an `else` branch after the insufficient payment check:

```swift
if payment <= firstMonthInterest {
    alert = .insufficientPayment(minimum: ...)
} else {
    alert = byPaymentTermAlert(balance: balance, apr: apr,
        payment: payment, startMonth: raw.startMonth, startYear: raw.startYear)
}
```

**Why the existing rounding wasn't the issue:** `firstMonthInterestEstimate` already rounded to 2 decimal places correctly. The bug was a missing check, not a precision error.

---

### Bug 2 — Chart tooltip never appeared on tap

**Discovered in:** Chunk 4.1 ride-through

**Symptom:** Tapping anywhere on the payoff chart never displayed a tooltip, regardless of term length or where on the chart was tapped.

**Root cause:** The Phase 3 implementation included a 1-month tolerance gate (~30 days in seconds) before setting `selectedRow`. The ChartProxy returns a `Date` value interpolated from the tap's X position — this date rarely lands exactly on the first of a month, which is what all `AmortizationRow.date` values are. For any month past month 1, the delta between the interpolated tap date and the nearest row's first-of-month date routinely exceeded the 30-day tolerance, so `selectedRow` was never set and the tooltip never appeared.

**Fix applied:** Removed the tolerance gate entirely in `handleChartTap`. The nearest row is always selected on any tap within the chart area:

```swift
// Before
let tolerance: TimeInterval = 30 * 24 * 60 * 60
if abs(nearest.date.timeIntervalSince(date)) < tolerance {
    selectedRow = nearest
}

// After
selectedRow = nearest
```

**Rationale:** A user tapping anywhere on the chart intends to see a data point. Always selecting the nearest row is the correct UX. The tolerance gate added no user-visible benefit and actively blocked the feature.

---

## iPad scaling — known cosmetic gap (not a bug)

**Chunk 4.6** confirmed the app is functional on iPad. Content is centered, capped at `BeaconLayout.maxContentWidth` (600pt), and nothing clips or overflows. However, significant whitespace exists in the margins at full iPad width.

This is expected and accepted for v1. The two-column iPad layout (form left, results right) is formally scoped for v1.1 per PRD §10. No action needed before App Store submission.

**Additional note:** `BeaconLayout.screenMarginLarge` (24pt) is defined in the design system but is not yet applied conditionally on iPad — the app uses the iPhone margin (16pt) on both. This is a minor cosmetic gap, also deferred to v1.1.

---

## Simulator issue encountered during testing

When switching between a physical device connection and the simulator during Chunk 4.1, the simulator entered a stuck state with error `FBSOpenApplicationServiceErrorDomain / Application failed preflight checks`. Resolved by running:

```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

This is an Xcode/simulator state issue unrelated to Beacon's code. Worth noting for future sessions: always quit and relaunch the Simulator app cleanly after disconnecting a physical device.

---

## App Store prep — deferred (Chunk 4.7)

Chunk 4.7 requires an Apple Developer Program membership ($99/year) for:
- TestFlight distribution
- Physical device installation outside development
- App Store submission

All remaining 4.7 tasks are documented and ready to execute once a developer account is active:

| Task | Notes |
|---|---|
| App icon | 1024×1024 PNG, no alpha |
| Screenshots | 6.7", 6.1", 12.9" iPad required sizes |
| App Store description | Lead with core value prop; include legal disclaimer mention |
| Keywords | 100 char limit; credit card debt, payoff calculator, amortization, debt free plan, interest calculator |
| Privacy policy URL | Required by App Store even though Beacon collects no data |
| TestFlight build | Archive → distribute → install on physical device |
| Final on-device QA | Repeat Chunk 4.1 ride-through on real hardware |

---

## Files modified in Phase 4

```
Beacon/Domain/Validation/
└── InputValidator.swift         ← added byPaymentTermAlert helper;
                                    updated byPayment alert block with else branch

Beacon/Features/PayoffPlanner/Results/
└── PayoffChartView.swift        ← removed tolerance gate in handleChartTap

Beacon/Features/PayoffPlanner/
└── BeaconViewModel.swift        ← added empty-rows guard in calculate()

Docs/beacon-results-from-phase-4.md  ← this file
```

No other Phase 1–3 files were modified. All changes are backward compatible.

---

## v1.0 feature completion status

| Feature | Status |
|---|---|
| Repayment input form with validation | ✅ Complete |
| Compound interest calculation engine | ✅ Complete |
| Amortization table (360-month, LazyVStack) | ✅ Complete |
| Balance payoff curve chart with tap-to-tooltip | ✅ Complete |
| Inline alerts — insufficient payment, term exceeds max | ✅ Complete |
| Summary stats with hero payoff date | ✅ Complete |
| Recalculation flow — sticky bar, stale notice, smooth scroll | ✅ Complete |
| Disclaimer footer | ✅ Complete |
| Accessibility pass | ✅ Complete |
| Performance validated (360-row, <1 second) | ✅ Complete |
| Error state completeness | ✅ Complete |
| iPad functional (cosmetic gap deferred to v1.1) | ✅ Accepted |
| App Store submission | ⏸ Pending developer account |

---

## What comes next

**To ship v1.0:** Activate an Apple Developer account and complete Chunk 4.7. The codebase is submission-ready.

**For v1.1**, the formally scoped roadmap items are (per PRD §10):

| Feature | Notes |
|---|---|
| Shareable amortization table (PDF/image export) | `PayoffPlan` is already serializable; `AmortizationRow` values fully computed at calc time — no recalculation needed at export |
| Multiple credit card support | Primary candidate for premium tier gating |
| iPad two-column layout | Form left, results right; `BeaconLayout.maxContentWidth` and `screenMarginLarge` tokens already in place |
| Android version | After iOS v1 is stable and validated |
| Chart line animation on render | `BeaconMotion.appearance` is the natural seam |
| Auto-payment reminders | Push notification infrastructure |
| Financial institution integration | Balance/APR read from connected card account |
| Premium tier / in-app purchase | Multiple card support as first gate |

---

*Beacon Phase 4 results — captured at v1.0 feature complete. Codebase is ready for App Store submission pending an Apple Developer account.*
