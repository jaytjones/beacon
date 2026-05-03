# Beacon — Known Issues

Living document of known bugs, design gaps, and behaviors that diverge from the spec or from user expectation. Each entry should record what's wrong, how to reproduce it, what test pins it, and the recommended fix path.

---

## Calculator: `byMonths` mode payment derivation gap

**Severity:** Low — ±1 row drift accepted for v1. (Originally Medium; downgraded after the catastrophic case was caught at the validator layer in Phase 2.2.)

**Status:** Catastrophic case resolved at the validator layer. ±1 row drift remains as accepted v1 behavior.

### Issue

`AmortizationCalculator.derivedMonthlyPayment` uses the monthly rate approximation `APR / 12` to compute the payment from a target term. Per-row interest, however, uses the daily rate `APR / 365 × daysInMonth`. For 31-day months, the daily-rate equivalent works out to `31/365 × APR ≈ APR × 1.0193 / 12` — slightly higher than the `APR / 12` the derivation assumed.

The two formulas don't perfectly cancel, so the row-by-row loop accumulates slightly more (or less) interest than the derivation expected. The size of the drift depends on the starting month, the term length, and the APR.

### How it manifests

The gap shows up at every term length, but the user-visible impact varies:

* **Short terms (e.g., 24 months at 24.99% APR):** plan comes in at requested ± 1 rows. Final balance still zeros cleanly thanks to the final-month adjustment; the user-visible artifact is just one extra or fewer row in the amortization table than they asked for.
* **Long terms at high APR (e.g., 360 months at 18% APR with a 31-day starting month):** the derived payment can fall below the first month's daily-rate interest charge entirely. Balance never decreases. The engine hits its `monthNumber > maxMonths` safety valve and returns an empty plan rather than amortizing.

### Reproduces

Short-term drift:

```
RepaymentInput(balance: 5000, apr: 24.99, mode: .byMonths,
               months: 24, startMonth: 5, startYear: 2026)
// → returns 25 rows, not 24
```

Long-term failure (now caught by the validator before reaching the engine):

```
RepaymentInput(balance: 10000, apr: 18, mode: .byMonths,
               months: 360, startMonth: 1, startYear: 2026)
// → calculator would return PayoffPlan with empty rows
// → validator now surfaces months-field error: "At this APR, your balance
//   won't be paid off in this many months. Try a longer term."
```

### Pinned by tests

* `AmortizationCalculatorTests.test_byMonths_producesPlanWithinOneMonthOfRequested` — accepts ±1 row count for byMonths mode at short terms
* `AmortizationCalculatorTests.test_byMonths_atCeilingWithHighAPR_returnsEmptyPlan` — locks in the empty-plan return at 360-month ceiling (calculator-side defensive behavior; validator now catches the case before reaching here)
* `BeaconViewModelTests.test_calculate_withValidByMonthsInput_producesPlan` — asserts ±1 row tolerance through the ViewModel layer
* `InputValidatorTests.test_byMonths_atCeilingWithHighAPR_surfacesMonthsFieldError` — locks in the validator catch for the catastrophic case

### Tech spec reference

§5.2 acknowledges the monthly/daily mismatch ("The monthly payment derivation from a target number of months uses the standard monthly rate approximation (`APR / 12`)... per-row interest still uses the daily rate") but doesn't analyze when it produces drift or non-amortizing payments.

### Possible fixes for v1.x (historical context)

1. **Bump the derived payment.** After computing payment in `derivedMonthlyPayment`, check it covers the worst-case (31-day) first-month interest using the daily rate, and increase it by a cent or two if not. Cheap, localized, but doesn't address the row-count drift at short terms.
2. **Replace the monthly approximation.** Use a daily-rate-equivalent monthly rate based on average days/month (`APR / 365 × 30.4375`) instead of `APR / 12`. Closer to mathematical correctness, but the standard amortization formula was derived assuming `APR / 12`, so this is a deeper change than it looks.
3. **Catch in validation.** `InputValidator` projects the term and surfaces problematic combinations as field errors or alerts before reaching the engine. Most consistent with the tech spec's design (engine assumes valid input; alerts fire upstream). Doesn't fix the drift itself, but prevents the user from ever seeing the worst manifestations.

### Resolution

**Option 3 (validation-layer catch) was implemented in Phase 2.2.** `InputValidator.byMonthsFeasibilityError` projects the derived monthly payment against the actual first-month interest at the user's start month. When the derived payment doesn't cover that interest — meaning the calculator would loop forever and trip its safety valve — the validator surfaces a months-field error: *"At this APR, your balance won't be paid off in this many months. Try a longer term."* The user sees a clear message instead of an empty results pane.

Note: the check uses the **actual** start-month days, not worst-case 31. The same balance + APR + months combination passes validation for some start months and fails for others — exactly matching the calculator's behavior, no false positives. The check also fires more broadly than the 360-month example in this issue: it correctly catches `(10000, 18%, 300 months, January start)` and similar combinations where the derived payment is below first-month interest.

The short-term ±1 row drift remains **accepted for v1**. Final balance is correct, payoff date is within a month of expected, and the table reads cleanly. Revisit if user testing surfaces complaints.

---

## (Add new issues above this line)
