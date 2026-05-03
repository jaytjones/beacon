# Beacon — Known Issues

Living document of known bugs, design gaps, and behaviors that diverge from the spec or from user expectation. Each entry should record what's wrong, how to reproduce it, what test pins it, and the recommended fix path.

---

## Calculator: `byMonths` mode payment derivation gap

**Severity:** Medium — math drift is real and produces user-visible artifacts at all term lengths. Catastrophic only at the 360-month ceiling.

### Issue

`AmortizationCalculator.derivedMonthlyPayment` uses the monthly rate approximation `APR / 12` to compute the payment from a target term. Per-row interest, however, uses the daily rate `APR / 365 × daysInMonth`. For 31-day months, the daily-rate equivalent works out to `31/365 × APR ≈ APR × 1.0193 / 12` — slightly higher than the `APR / 12` the derivation assumed.

The two formulas don't perfectly cancel, so the row-by-row loop accumulates slightly more (or less) interest than the derivation expected. The size of the drift depends on the starting month, the term length, and the APR.

### How it manifests

The gap shows up at every term length, but the user-visible impact varies:

- **Short terms (e.g., 24 months at 24.99% APR):** plan comes in at requested ± 1 rows. Final balance still zeros cleanly thanks to the final-month adjustment; the user-visible artifact is just one extra or fewer row in the amortization table than they asked for.
- **Long terms at high APR (e.g., 360 months at 18% APR with a 31-day starting month):** the derived payment can fall below the first month's daily-rate interest charge entirely. Balance never decreases. The engine hits its `monthNumber > maxMonths` safety valve and returns an empty plan rather than amortizing.

### Reproduces

Short-term drift:
```swift
RepaymentInput(balance: 5000, apr: 24.99, mode: .byMonths,
               months: 24, startMonth: 5, startYear: 2026)
// → returns 25 rows, not 24
```

Long-term failure:
```swift
RepaymentInput(balance: 10000, apr: 18, mode: .byMonths,
               months: 360, startMonth: 1, startYear: 2026)
// → returns PayoffPlan with empty rows
```

### Pinned by tests

- `AmortizationCalculatorTests.test_byMonths_producesPlanWithinOneMonthOfRequested` — accepts ±1 row count for byMonths mode at short terms
- `AmortizationCalculatorTests.test_byMonths_atCeilingWithHighAPR_returnsEmptyPlan` — locks in the empty-plan return at 360-month ceiling
- `BeaconViewModelTests.test_calculate_withValidByMonthsInput_producesPlan` — asserts ±1 row tolerance through the ViewModel layer

### Tech spec reference

§5.2 acknowledges the monthly/daily mismatch ("The monthly payment derivation from a target number of months uses the standard monthly rate approximation (`APR / 12`)... per-row interest still uses the daily rate") but doesn't analyze when it produces drift or non-amortizing payments.

### Possible fixes for v1.x

1. **Bump the derived payment.** After computing payment in `derivedMonthlyPayment`, check it covers the worst-case (31-day) first-month interest using the daily rate, and increase it by a cent or two if not. Cheap, localized, but doesn't address the row-count drift at short terms.

2. **Replace the monthly approximation.** Use a daily-rate-equivalent monthly rate based on average days/month (`APR / 365 × 30.4375`) instead of `APR / 12`. Closer to mathematical correctness, but the standard amortization formula was derived assuming `APR / 12`, so this is a deeper change than it looks.

3. **Catch in validation.** `InputValidator` projects the term and surfaces problematic combinations as field errors or alerts before reaching the engine. Most consistent with the tech spec's design (engine assumes valid input; alerts fire upstream). Doesn't fix the drift itself, but prevents the user from ever seeing the worst manifestations.

### Recommendation

**Option 3 (validation-layer catch)** for the long-term/empty-plan case — it matches the spec's separation of concerns and gives the user a clear error message instead of an empty results pane.

For the short-term ±1 drift, **accept it for v1**. Users don't have a reason to count rows. The final balance is correct, the payoff date is within a month of expected, and the table reads cleanly. Revisit if user testing surfaces complaints.

---

## (Add new issues above this line)
