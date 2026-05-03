# Beacon
## Product Requirements Document
**Version 1.0 | May 2026**

---

## 1. Executive Summary

Beacon is a native iOS app that gives credit card holders a clear, actionable month-by-month payoff plan. Users enter their balance, APR, and repayment preference and receive a detailed amortization table and visual payoff curve — replacing guesswork with a concrete, motivating roadmap to zero.

The app targets mobile users in their mid-20s to mid-30s who are ready to act on their debt but lack the tools to make a realistic plan. Beacon wins by combining amortization-level detail, an anchored start date, and a clean native iOS experience free of ads and noise.

---

## 2. Problem Statement

> People actively carrying credit card debt lack a clear, visual payoff plan — they are guessing at timelines and payments, which makes debt feel nebulous and insurmountable. Existing calculators give a number but not the actionable, month-by-month picture needed to stay motivated and realistic.

---

## 3. Target Users

### Primary Persona — "Motivated Marcus"

| Attribute | Detail |
|---|---|
| Age | Mid-20s to mid-30s |
| Trigger | Opened a statement that finally made the balance feel real |
| Goal | A clear plan they can point to and say "this is how I get out" |
| Frustration today | Guessing at payments with no sense of how long it will actually take |
| Technical comfort | Uses apps daily; expects a polished, fast mobile experience |
| Emotional state | Motivated and ready to act — not in denial |
| Mindset quote | "I need to see exactly what this looks like, month by month." |

### Secondary Persona — "Accessible Alex"

Same trigger as Marcus, but lower financial literacy. Needs the UI to guide without overwhelming. No jargon, clear labels, and plain-language error messages are critical for this user.

### Jobs to Be Done

| Job Type | The job Beacon is hired to do |
|---|---|
| **Functional** *(primary)* | Calculate exactly when my debt is gone and what it costs me each month |
| **Emotional** *(secondary)* | Make me feel like this is actually doable — replace dread with a plan |
| **Social** *(v1.1)* | Give me something concrete I could show a partner, friend, or advisor |

---

## 4. Goals & Success Metrics

| Dimension | Target |
|---|---|
| Primary goal | Help users create a realistic, personalized debt payoff plan in under 2 minutes |
| Secondary goal | Make the payoff timeline feel concrete and achievable, not abstract |
| 3-month metric | App Store rating ≥ 4.5 \| Avg session completes a full calculation |
| 6-month metric | Retain 40%+ of users who return for a second session (recalculation) |
| 1-year metric | Social sharing feature (v1.1) drives measurable organic downloads |
| Successful user | A user who completes a calculation, scrolls the amortization table, and interacts with the payoff chart |

---

## 5. v1 Feature List

---

### Feature 1: Repayment Input Form

**User Story:** As a user carrying credit card debt, I want to enter my balance, APR, and either a target number of months or a monthly payment amount, so that I can generate a personalized payoff plan.

**Acceptance Criteria:**
- User can enter current balance as a positive dollar amount
- User can enter APR as a positive percentage with inline placeholder: *e.g. 24.99 for 24.99% APR*
- Repayment mode displayed as a pill toggle: **By months** | **By payment amount** — tapping switches the active input field
- Start date uses two dropdowns: Month (January–December) and Year (current year + 10 years forward)
- Start date defaults to current month and year
- All fields validate on submission with inline error messages — not a generic alert
- Calculate button is disabled until all required fields are populated and valid
- After first successful calculation, a sticky **Recalculate bar** appears at the top of the viewport
- Tapping the Recalculate bar scrolls the user back to the input form
- When any field is edited after a calculation, an inline notice appears below the form and above results: *"Your inputs have changed — tap Calculate to update your plan."*
- Layout is optimized for SwiftUI on iPhone; scales to iPad using the same layout in v1

**Explicitly Does NOT:**
- Support multiple cards in v1
- Save or remember previous inputs between sessions

**Edge Cases to Handle:**
- APR entered as whole number vs. decimal (e.g. 24 vs. 0.24) — clear inline label prevents this
- User switches repayment mode mid-entry — alert and validation state resets cleanly
- Balance of $0 entered — inline error: *"Please enter a balance greater than $0"*

---

### Feature 2: Compound Interest Calculation

**User Story:** As a user, I want the app to accurately calculate my monthly interest charges using compound interest based on a daily rate, so that my payoff plan reflects what I will actually owe each month.

**Acceptance Criteria:**
- Interest calculated using the daily periodic rate: APR ÷ 365
- Monthly interest charge: daily rate × number of days in the month × current balance
- Principal paid = monthly payment − interest charge for that month
- Remaining balance = previous balance − principal paid
- Final month payment is adjusted to the exact remaining balance — no overpayment shown
- All currency values displayed to exactly 2 decimal places throughout
- Calculation completes in under 1 second for all terms up to 360 months

**Explicitly Does NOT:**
- Account for fees, penalties, or card-issuer minimum payment requirements
- Assume a fixed 30-day month — actual day count per month is used for accuracy

**Edge Cases to Handle:**
- Final month where remaining balance is less than the regular payment amount — adjust final payment accordingly
- Floating point rounding — all currency rounded to exactly 2 decimal places
- APR of 0% — valid input, must calculate correctly without errors
- Payment results in a term exceeding 360 months — trigger the long-term alert (see Feature 5)

---

### Feature 3: Amortization Table

**User Story:** As a user, I want to see a month-by-month breakdown of my payments so that I can understand exactly how my balance decreases over time and stay motivated.

**Acceptance Criteria:**
- Table renders immediately after calculation — no separate load step
- Columns: Month #, Month Name + Year, Payment Amount, Interest Paid, Principal Paid, Remaining Balance
- All currency columns formatted as $X,XXX.XX
- Table uses infinite scroll — all rows rendered, no pagination
- Rows use alternating visual treatment for readability on mobile
- Final row clearly indicates $0.00 remaining balance
- Table scrolls independently on mobile without hijacking the main page scroll
- Supports terms up to 360 months (30 years) maximum

**Explicitly Does NOT:**
- Allow inline editing of individual rows
- Support exporting or sharing in v1

**Edge Cases to Handle:**
- Very short terms (1–3 months) — table renders cleanly at small row counts
- Terms beyond 360 months are not allowed — long-term alert triggers before table renders

---

### Feature 4: Balance Payoff Curve Chart

**User Story:** As a user, I want to see a visual line graph of my balance decreasing to zero over time, so that my payoff plan feels tangible and motivating at a glance.

**Acceptance Criteria:**
- Line graph renders immediately alongside the amortization table after calculation
- X-axis: Month Name + Year, labeled at regular intervals (not every month for longer terms)
- Y-axis: Remaining balance, formatted as $X,XXX — scale adjusts dynamically to starting balance
- Line originates at the starting balance and terminates at $0.00
- Tapping any point on the line displays a tooltip: Month Name + Year and Remaining Balance at that month
- Tooltip is dismissible by tapping elsewhere on the chart
- Chart renders responsively and cleanly on all modern iPhone screen sizes
- Chart and amortization table stay in sync — they always reflect the same calculation
- Built using SwiftUI Charts framework (iOS 16+) with `.chartOverlay` for touch interaction

**Explicitly Does NOT:**
- Support multiple data series in v1 (e.g. comparing two payoff scenarios)
- Animate the line on render in v1

**Edge Cases to Handle:**
- Very short terms (1–3 months) — chart renders with adequate point spacing, not cramped
- Y-axis scale adjusts dynamically for both small (e.g. $500) and large (e.g. $15,000) balances
- High APR + low payment resulting in a nearly flat curve — chart must still communicate progress clearly

---

### Feature 5: Alerts & Validation

**User Story:** As a user, I want to be clearly warned if my payment is too low or my repayment term is unrealistic, so that I don't walk away with a false or impossible plan.

**Acceptance Criteria:**

*Insufficient Payment Alert:*
- Triggers if the entered monthly payment is ≤ the first month's interest charge
- Displayed inline within the input form — not a modal or browser alert
- Plain-language message with the calculated minimum: *"Your payment doesn't cover the monthly interest. Try increasing it to at least $X."*
- Calculate button remains disabled while alert condition is active
- Alert clears automatically when the user adjusts the payment to a valid amount
- Error state uses icon + text — not color alone (accessibility requirement)

*Long-Term Alert:*
- Triggers if a valid payment would result in a repayment term exceeding 360 months
- Plain-language message: *"At this payment amount, your balance won't be paid off within 30 years. Try increasing your monthly payment."*
- Same inline treatment as the insufficient payment alert

**Explicitly Does NOT:**
- Block the user from editing other fields while an alert is shown
- Use red color alone to communicate errors

**Edge Cases to Handle:**
- User switches from monthly payment mode to months mode mid-entry — alert state resets
- User corrects payment — alert dismisses automatically, Calculate button re-enables

---

## 6. User Flows

### Flow 1: Primary Calculation Flow (Happy Path)

**Trigger:** User opens the app with a statement balance in mind, ready to make a plan.

1. App loads — empty input form, no table or chart visible
2. User enters current balance
3. User enters APR
4. User selects repayment mode via pill toggle (defaults to **By months**)
5. User enters their value for the chosen mode
6. User selects start month and year (defaults to current month)
7. All fields valid — Calculate button activates
8. User taps Calculate
9. Amortization table and payoff chart render below the form
10. Sticky Recalculate bar appears at the top of the viewport
11. User scrolls through table and interacts with chart tap states

**Decision Points:**
- Repayment mode toggle — determines which input field is shown
- Start date — defaults to current month but user can override

**✅ Success:** Table and chart render with a complete, valid payoff plan

**❌ Failure:** Any invalid input — inline error on that field, Calculate button remains disabled

---

### Flow 2: Insufficient Payment Flow

**Trigger:** User enters a monthly payment that does not cover the first month's interest charge.

1. User completes all fields in By payment amount mode
2. System detects payment ≤ first month's interest charge
3. Inline alert appears with suggested minimum payment amount
4. Calculate button remains disabled

**Decision Points — User either:**
- **Path A:** Adjusts payment upward — alert dismisses, Calculate activates, proceeds to Flow 1 success
- **Path B:** Switches to By months mode — alert clears, user enters months, proceeds to Flow 1 success

**✅ Success:** User adjusts input and generates a valid plan

**❌ Failure:** User abandons without adjusting — no calculation runs, no bad data is shown

---

### Flow 3: Recalculation Flow

**Trigger:** User has already generated a plan and wants to try a different scenario.

1. User views amortization table and chart
2. User taps the sticky Recalculate bar — scrolls back to the input form
3. User edits one or more fields
4. Inline notice appears below the form, above the results: *"Your inputs have changed — tap Calculate to update your plan."*
5. Previous results remain visible for reference while the notice is shown
6. User taps Calculate
7. Notice dismisses, table and chart update in place with new results — no page reload

**Decision Points:**
- If edited input creates a new validation error — inline field error shown, stale notice remains, previous results persist until a valid recalculation runs

**✅ Success:** Table and chart update smoothly to reflect the new scenario

**❌ Failure:** New input is invalid — error shown inline, previous results remain as reference

---

## 7. Error & Empty States

### Input Form — Empty State (First Load)

| State | UI Behavior |
|---|---|
| App first opens | Empty form, placeholder text visible, Calculate button disabled, no table or chart |
| Pill toggle default | **By months** selected — monthly payment input hidden |
| Date picker default | Current month and year pre-selected |

### Input Form — Error States

| Trigger | Message |
|---|---|
| Balance blank or $0 | *"Please enter a balance greater than $0"* |
| Balance non-numeric | *"Please enter a valid dollar amount"* |
| APR blank | *"Please enter your APR"* |
| APR of 0% | Allowed — calculates correctly, no error |
| APR over 100% | *"Please enter a valid APR — most credit cards are between 15% and 30%"* |
| Months blank | *"Please enter a number of months"* |
| Months is 0 or negative | *"Please enter a repayment term of at least 1 month"* |
| Monthly payment ≤ interest | *"Your payment doesn't cover the monthly interest. Try increasing it to at least $X."* |
| Term exceeds 360 months | *"At this payment amount, your balance won't be paid off within 30 years. Try increasing your monthly payment."* |
| Any field non-numeric | *"Please enter numbers only"* |

### Results — States

| State | UI Behavior |
|---|---|
| Calculation running | Spinner on Calculate button — resolves in under 1 second |
| Results loaded | Table and chart render; sticky Recalculate bar appears |
| Inputs edited post-calculation | Stale data notice appears below form, above results |
| Recalculation running | Spinner on Recalculate button |
| No results yet | Table and chart area is hidden — no empty placeholder shown |

### Chart — States

| State | UI Behavior |
|---|---|
| Chart loaded | Line graph renders with axes; no tooltip visible |
| User taps a data point | Tooltip appears: Month + Year, Remaining Balance |
| User taps elsewhere | Tooltip dismisses |
| Very short term (1–3 months) | Chart renders with adequate point spacing |

---

## 8. Non-Functional Requirements

| Requirement | Decision |
|---|---|
| Platform | Native iOS — Swift + SwiftUI |
| iOS minimum | iOS 16+ |
| iPhone support | All modern screen sizes — primary target |
| iPad v1 | Scaled iPhone layout |
| Distribution | Apple App Store |
| Android | Out of scope for v1 |
| Performance | Calculation + full render in under 1 second for all terms up to 360 months |
| Offline | Not required for v1 — assumes active connection |
| Data & Privacy | All calculations run client-side; no financial data transmitted or persisted |
| Authentication | None required for v1 — fully open access |
| Accessibility | Color-independent errors (icon + text required); minimum tap targets per iOS HIG; basic screen reader support |
| Regulatory | No HIPAA/COPPA/GDPR obligations triggered by v1 feature set |
| Legal disclaimer | *"Beacon provides estimates only and does not constitute financial advice"* — displayed in UI footer |
| Monetization | Free in v1; architecture should be premium-tier ready for v1.1 |

---

## 9. Out of Scope (v1)

The following are explicitly excluded from v1 and must not be designed for or built against:

1. Multiple credit card support
2. Shareable or exportable amortization table
3. iPad two-column layout (form left, results right)
4. Android version
5. Chart line animation on render
6. Auto-payment setup or reminders
7. Financial institution integration
8. User accounts, login, or data persistence between sessions
9. Premium tier paywall or in-app purchase infrastructure
10. Push notifications

---

## 10. v1.1 Roadmap

The following features are formally scoped for v1.1. They have been excluded from v1 to maintain launch focus but are planned and should be considered in v1 architectural decisions where relevant.

| Feature | Description |
|---|---|
| **Shareable amortization table** | Allow users to export or share their payoff plan as a PDF or image — supports the social job-to-be-done and drives organic growth |
| **Multiple credit card support** | Users can add more than one card, each with its own balance and APR, and view a combined or individual payoff plan — primary candidate for the premium tier |
| **iPad two-column layout** | Dedicated iPad layout with the input form on the left and the table and chart on the right — leverages the larger screen meaningfully |
| **Android version** | Parity app for Android, built after iOS v1 is stable and validated with users |
| **Chart line animation** | Animated line draw on chart render — adds delight and reinforces the emotional payoff of seeing the balance drop to zero |
| **Auto-payment reminders** | Optional push notifications reminding the user of their planned payment date each month |
| **Financial institution integration** | Advanced: read balance and APR directly from a connected card account — removes manual entry friction |
| **Premium tier / paywall** | Introduce a paid tier gating advanced features (likely multiple card support as the first gate); in-app purchase infrastructure to be added in v1.1 |

---

## 11. Open Questions

All open questions from the PRD process have been resolved. None are outstanding at the time of this document's publication.

| Question | Resolution |
|---|---|
| App name | **Beacon** |
| Maximum repayment term | **360 months (30 years)** — table and chart support all terms up to this ceiling |
| Behavior when payment results in term > 360 months | **Alert triggered** — inline message prompts user to increase payment |

---

*Beacon PRD v1.0 — Built using the PRD Creation Guide process (jaytjones/app-building-tools). Ready for handoff to technical spec.*
