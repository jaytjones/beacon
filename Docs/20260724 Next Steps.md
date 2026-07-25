# Beacon — Codebase Review & Next Steps

**Date:** 24 July 2026
**Scope:** Full-repo review of UI, code architecture, and engineering infrastructure against best practices, followed by a proposed feature roadmap.
**Reviewed at commit:** `605c105` (branch `main`, clean tree)
**Codebase size:** ~2,400 lines Swift across 30 source files; 635 lines of tests; ~1,900 lines of docs.

---

## 0. Executive Summary

Beacon is in better shape than most v1 codebases at this stage. The domain layer is genuinely well built — the `Decimal`-throughout calculation engine, the pure-Swift validator, and the strict separation between `Domain/`, `DesignSystem/`, and `Features/` are the right architecture, well documented, and correctly tested where tested at all. The design system is unusually disciplined: real tokens, documented exceptions, and a usage guide that records *why* decisions were made.

The gap is not architecture. It is **launch readiness**. The app currently has one state-management defect that hard-bricks the UI, several pieces of Xcode-template debris that will fail or complicate App Store review, no repository hygiene (no `.gitignore`, no CI, no linter, no README), and an accessibility story that is claimed in the tech spec but not implemented in the chart or under Dynamic Type. Test coverage is heavily skewed — 30 tests on the calculator, one test on the 307-line validator, and zero real UI tests.

### Scorecard

| Area | Grade | One-line assessment |
|---|---|---|
| Domain / calculation engine | **A−** | `Decimal` discipline, good edge-case tests, one accepted known drift |
| Design system | **A−** | Real tokens, documented exceptions; two dead tokens, one empty stub file |
| Architecture & separation | **B+** | Clean MVVM; ViewModel is doing slightly too much and has a state bug |
| View layer / SwiftUI quality | **C+** | Works, but formatting is inconsistent and duplicated; several dead code paths |
| UX correctness | **C** | Premature validation errors, no keyboard dismissal, layout jump on chart tap |
| Accessibility | **C−** | Table and fields are good; chart has none; Dynamic Type will break the table |
| Test coverage & strategy | **C** | Excellent calculator tests; validator and UI essentially untested |
| Engineering infrastructure | **D** | No `.gitignore`, no CI, no linter, no README, no test plan |
| App Store readiness | **D** | No app icon, unused push/CloudKit entitlements, empty accent color |
| Documentation | **A** | Genuinely excellent — PRD, tech spec, phase results, KNOWN_ISSUES |

### The five things that matter most

1. **`BeaconViewModel.calculate()` can permanently disable the Calculate button** (§1.1) — hard blocker.
2. **Unused push-notification and CloudKit entitlements + `UIBackgroundModes`** (§1.2) — will draw App Store review questions and breaks automatic provisioning.
3. **No app icon and an empty accent color** (§1.3) — cannot submit; the system tint is default blue, fighting the sage design system.
4. **Validation errors appear on fields the user has not typed in yet** (§2.1) — the single worst first-run UX moment in the app.
5. **No `.gitignore`, no CI, no linter** (§4) — everything else regresses silently without this.

---

# Part 1 — Blocking Defects

These prevent shipping. Fix before anything else.

## 1.1 The Calculate button can lock permanently — `isCalculating` is never reset on the error path

[BeaconViewModel.swift:112-127](../Beacon/Features/PayoffPlanner/BeaconViewModel.swift#L112-L127)

```swift
isCalculating = true
let result = AmortizationCalculator.calculate(input: input)

guard !result.rows.isEmpty else {
    self.alertType = .termExceedsMax
    return                      // ← isCalculating stays true forever
}

self.plan = result
hasStaleResults = false
isCalculating = false
```

**Impact.** `PrimaryButton.isInteractive` is `isEnabled && !isLoading`. When the calculator returns an empty plan, `isCalculating` stays `true`, so the button renders a spinner and is `.disabled(true)` — permanently. The user cannot recalculate, and nothing in the app can reset it. Only relaunching clears it. This is the exact failure class the last two commits were chasing.

**Second, subtler problem in the same block.** On the success path, `isCalculating` is set `true` and `false` within a single synchronous run-loop turn. SwiftUI never renders the intermediate state, so the spinner is *unobservable in normal operation*. The loading affordance only ever appears when it is stuck. The state is simultaneously dead code and a footgun.

**Recommended fix.** Use `defer { isCalculating = false }` immediately after setting it true, and either delete the loading state entirely (the calculation is genuinely sub-millisecond, so `PrimaryButton.isLoading` earns nothing) or move the calculation off the main actor so the spinner has a reason to exist. Deleting it is the honest choice for v1.

**Third issue in the same block.** The `guard` surfaces `.termExceedsMax`, whose copy reads *"Try increasing your monthly payment"* — wrong and confusing for a `byMonths` user, who has no payment field on screen. Either make the fallback alert mode-aware or, better, treat the empty-plan return as an internal invariant violation, since the validator is now supposed to catch every path that produces it.

## 1.2 Unused push-notification and CloudKit entitlements

[Beacon/Beacon.entitlements](../Beacon/Beacon.entitlements) declares `aps-environment: development` and `com.apple.developer.icloud-services: [CloudKit]`.
[Beacon/Info.plist](../Beacon/Info.plist) declares `UIBackgroundModes: [remote-notification]` — and is otherwise empty.

The PRD explicitly excludes push notifications (§9 item 10) and all persistence (§9 item 8). Nothing in the codebase registers for remote notifications, and no CloudKit container is configured (the identifier array is empty).

**Impact.** Automatic signing will try to provision push and iCloud capabilities the app has no entitlement to use. App Review routinely asks why an app declares a background mode it never exercises, and an empty CloudKit container array is a known provisioning-failure trigger. This is Xcode template debris, not intent.

**Fix.** Delete both entitlement keys and the `UIBackgroundModes` array. If `Info.plist` ends up empty, drop the file and rely on `GENERATE_INFOPLIST_FILE = YES`, which is already enabled.

## 1.3 No app icon, no accent color

- [AppIcon.appiconset](../Beacon/Assets.xcassets/AppIcon.appiconset/) contains only `Contents.json` with three empty 1024×1024 slots — light, dark, and tinted. **There is no image.** The app cannot be submitted.
- [AccentColor.colorset](../Beacon/Assets.xcassets/AccentColor.colorset/Contents.json) defines no color values at all. Every system control that reads the app tint — the `Picker(.segmented)` selection, `Menu` checkmarks, text-field carets and selection handles — renders in default iOS blue, directly contradicting the design system's rule that sage is the app's only accent.

**Fix.** Produce the 1024px icon in all three appearances. Set `AccentColor` to the sage light/dark pair already defined as `beaconAccent` (`#5C8A6F` / `#7BA88C`) so system chrome matches the design system for free.

## 1.4 Dead SwiftData model still in the target

[Item.swift](../Beacon/Item.swift) is the untouched Xcode template `@Model final class Item`. It imports SwiftData into an app the tech spec states has **no persistence layer** (§2.3). It links a framework, appears in the binary, and directly contradicts the "no data persisted" privacy claim in PRD §8 that you will have to defend on the App Store privacy questionnaire.

**Fix.** Delete the file.

## 1.5 The project does not build on the current toolchain

`xcodebuild -scheme Beacon` fails locally:

```
iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components.
CoreSimulator is out of date. Current version (1051.50.0) is older than build version (1051.55.0).
```

I could not compile the project, so **every code finding below is from static reading, not from compiler or runtime verification.** Restoring a working build is a prerequisite for everything in Part 4 — you cannot add CI to a project that does not build on a clean machine.

There is also a **deployment-target mismatch**: the app target is `IPHONEOS_DEPLOYMENT_TARGET = 17.6`, while both test targets are set to `26.4`. The PRD and tech spec both specify **iOS 16**. Three different answers to the same question. Pick one — iOS 17 is a defensible modernization given `@Previewable` is already used in [MenuField.swift](../Beacon/DesignSystem/Components/MenuField.swift), which requires iOS 17 — and apply it uniformly, then update the PRD and tech spec to match.

---

# Part 2 — UI & UX Review

## 2.1 Validation errors fire on fields the user has not reached yet ⚠️ *highest-impact UX issue*

[BeaconViewModel.swift:154-177](../Beacon/Features/PayoffPlanner/BeaconViewModel.swift#L154-L177) revalidates the **entire form** on any field change. [InputValidator.validate](../Beacon/Domain/Validation/InputValidator.swift#L41) unconditionally appends an error for every empty required field.

**What the user experiences.** They type the first character of their balance. Instantly, two red-bordered fields appear below with *"Please enter your APR"* and *"Please enter a number of months"* — for fields they have not touched. On a form with three inputs, one keystroke produces two errors.

This directly undermines the "Accessible Alex" persona the PRD centers (§3), and it contradicts the PRD's own acceptance criterion: *"All fields validate on submission with inline error messages."* Submission, not keystroke.

**Recommended fix.** Track per-field "touched" state (set on focus loss) and only surface a field's error once it has been touched or once Calculate has been pressed. Keep the reactive pipeline exactly as it is for the *button enablement* and *inline alert* logic — it is correct there — and gate only the visual error rendering. This is a ~30-line change in the ViewModel plus a `touched` flag passed into `Field`.

## 2.2 The keyboard cannot be dismissed

Every input in the form is `.decimalPad` or `.numberPad` ([Field.swift](../Beacon/DesignSystem/Components/Field.swift), [BalanceField](../Beacon/Features/PayoffPlanner/InputForm/BalanceField.swift), [APRField](../Beacon/Features/PayoffPlanner/InputForm/APRField.swift), [MonthsField](../Beacon/Features/PayoffPlanner/InputForm/MonthsField.swift), [MonthlyPaymentField](../Beacon/Features/PayoffPlanner/InputForm/MonthlyPaymentField.swift)). **Numeric keyboards have no return key.** There is no `.toolbar { ToolbarItemGroup(placement: .keyboard) }`, no `.scrollDismissesKeyboard(.interactively)`, and no background tap-to-dismiss.

On an iPhone SE or mini, the keyboard covers roughly half the screen — including the Calculate button and all results. The user is trapped unless scrolling happens to shift focus.

**Fix.** Add a keyboard toolbar with a **Done** button, and `.scrollDismissesKeyboard(.interactively)` on the root `ScrollView`. Consider `.submitLabel(.next)` field-to-field focus advancement as a follow-on.

## 2.3 The chart jumps when you tap it

[PayoffChartView.swift:39-47](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L39-L47) places `ChartTooltipOverlay` as a **sibling above the chart inside a `VStack`**, conditionally. When the user taps a point, the tooltip is inserted into the layout flow, pushing the chart down by roughly 70pt — including the point they just tapped. Tap again and everything shifts back.

The file's own header comment says the tooltip is *"rendered by the parent (ResultsView) using ChartTooltipOverlay overlay on top of this chart"* — that is not what the code does.

**Fix.** Render it as a true `.overlay(alignment: .top)` on the `Chart` so it floats without displacing layout, or reserve the tooltip's height permanently with a hidden placeholder. The overlay is the better call and matches the documented intent.

## 2.4 Chart tap handling is dead code and uses the wrong modifier

[PayoffChartView.swift:119-141](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L119-L141):

```swift
guard let date = ..., let balance = proxy.value(atY: location.y, as: Double.self)
else { ... }                                    // `balance` is never used

let nearest = rows.min { a, b in ... }          // computed, then discarded

if let nearest = rows.min(by: { ... }) {        // the same computation again
    selectedRow = nearest
}
```

Three problems in twenty lines: `balance` is bound and unused (a compiler warning), `nearest` is computed twice with the second shadowing the first, and the comment *"Only select if the tap is reasonably close (within ~1 month tolerance)"* describes behavior the next line explicitly abandons — *"Simpler: always select the nearest row, no tolerance gate."*

Separately, the gesture is attached via `.chartBackground` ([line 100](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L100)), which sits **behind** the plot content. The tech spec (§1.2, Risk 1) specifies `.chartOverlay` for exactly this reason. It appears to work today because a `LineMark` has almost no hit area, but any future `PointMark` or area fill will start swallowing taps.

**Fix.** Migrate to `.chartOverlay`, remove the unused binding, compute `nearest` once, and delete the contradictory comments. Longer term, adopt `.chartXSelection(value:)` (iOS 17+) and delete the manual coordinate math entirely — this is the single biggest complexity reduction available in the view layer.

## 2.5 The X-axis label count is hardcoded, contradicting its own documentation

[PayoffChartView.swift:167-170](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L167-L170):

```swift
/// For short terms (< 12 months), show every month. For longer terms, space them out
private var axisLabelCount: Int {
    return 4        // always
}
```

A 3-month plan gets the same four labels as a 360-month plan. Phase 3 results document thresholds of 12 and 60 that no longer exist in the code. Either restore the responsive logic or delete the misleading doc comment and the phase-3 claim.

## 2.6 The hero number token is defined, documented, and never used

`Font.beaconHeroNumber` exists in [BeaconDesignSystem.swift:89-91](../Beacon/DesignSystem/BeaconDesignSystem.swift#L89-L91), the design system usage guide names it, and [SummaryRow.swift](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift) documents at length that the payoff date is the hero stat — then passes `isHero: false` at [line 55](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift#L55).

The result: three visually identical stat cards with no hierarchy. The emotional payoff the PRD is built around ("make me feel like this is actually doable", §3) is rendered in body text.

**Fix.** Decide deliberately. If the hero treatment is wanted, set `isHero: true` and let the card render at 28pt sage. If not, delete the token, the `isHero` parameter, and the paragraphs of documentation describing it. Both are fine; the current state — fully built, fully documented, switched off — is the only bad option.

## 2.7 Two currency formatting strategies produce different output

| Approach | Used in |
|---|---|
| `Decimal.formatted(.currency(code: "USD"))` — locale-aware, no float conversion | [AmortizationRowView](../Beacon/Features/PayoffPlanner/Results/AmortizationRowView.swift), [InlineAlertView](../Beacon/Features/PayoffPlanner/InputForm/InlineAlertView.swift) |
| `NumberFormatter` + `NSDecimalNumber → Double` | [SummaryRow](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift#L69-L75), [ChartTooltipOverlay](../Beacon/Features/PayoffPlanner/Results/ChartTooltipOverlay.swift#L69-L75), [PayoffChartView](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L148-L155) |

The second approach **converts `Decimal` to `Double` purely to format it** — reintroducing exactly the floating-point imprecision that tech spec §1.2 Risk 2 identifies as HIGH and that the entire engine is architected to avoid. It also allocates a fresh `NumberFormatter` inside the view body on every call (three per `SummaryRow` render, two per chart tap); `NumberFormatter` construction is genuinely expensive.

The same split exists for dates: `DateFormatter(dateFormat: "MMM yyyy")` — a **fixed, non-locale-aware pattern** — in [SummaryRow](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift#L77-L81), [ChartTooltipOverlay](../Beacon/Features/PayoffPlanner/Results/ChartTooltipOverlay.swift#L57-L61), and [PayoffChartView](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift#L158-L162), versus the correct `.formatted(.dateTime.month(.abbreviated).year())` in [AmortizationRowView](../Beacon/Features/PayoffPlanner/Results/AmortizationRowView.swift).

**Fix.** Create `Domain/Formatting/BeaconFormatters.swift` with two functions — `currency(_ d: Decimal) -> String` and `monthYear(_ d: Date, style:) -> String` — both built on the modern `.formatted` APIs, and route all five call sites through it. This deletes ~40 lines, removes the `Double` round-trip, makes output locale-correct, and gives you exactly one place to change when multi-currency arrives in v1.1.

## 2.8 Smaller UI observations

- **Segmented control truncation.** "By payment amount" in a two-segment `Picker` will truncate on iPhone SE / mini widths. Consider "By payment" or test at 320pt.
- **Tertiary color on the legal disclaimer.** [DisclaimerFooter](../Beacon/DesignSystem/Components/DisclaimerFooter.swift) renders the required regulatory text at `.beaconCaption` (11pt) in `.beaconTextTertiary` — a color the design system itself annotates as *"deliberately fails WCAG AA for normal text — only use it for hints, placeholders, and metadata the user doesn't need to read."* A legally required disclaimer is not metadata. Move to `.beaconTextSecondary`.
- **Stale-notice race.** If the user taps Calculate within 50ms of a keystroke, the pending debounced sink fires *after* `calculate()` sets `hasStaleResults = false` and flips it back to `true` — the "your inputs have changed" notice appears over freshly computed results. Low frequency, easy fix: compare against a snapshot of the inputs used for the current plan rather than using a boolean flag. That change also makes the notice correct when a user edits a field and then edits it back.
- **Full-bleed table comment is wrong.** [BeaconRootView.swift:17](../Beacon/App/BeaconRootView.swift#L17) says the table is full-bleed, but it sits inside the `maxWidth: 600` frame, so on iPad it is capped like everything else. Harmless; the comment is just stale.
- **Formatting debris.** Broken indentation at [SummaryRow.swift:36-63](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift#L36-L63) and [BeaconRootView.swift:56](../Beacon/App/BeaconRootView.swift#L56); `}else {` at [InputValidator.swift:134](../Beacon/Domain/Validation/InputValidator.swift#L134); trailing whitespace at [InputValidator.swift:263](../Beacon/Domain/Validation/InputValidator.swift#L263). All of this disappears the day a formatter lands (§4.3).

---

# Part 3 — Code & Architecture Review

## 3.1 What is working well

Worth stating plainly, because it is the foundation everything else builds on:

- **`Decimal` throughout the engine.** [AmortizationCalculator](../Beacon/Domain/Calculation/AmortizationCalculator.swift) never touches `Double`, uses `NSDecimalRound` with an explicit scale and rounding mode, and keeps the daily rate at full precision. This is the correct answer to a problem most calculator apps get wrong, and it is tested against known outputs.
- **Genuine layer separation.** `Domain/` imports only `Foundation`. The calculator has no knowledge of the validator; the validator has no knowledge of the ViewModel; the design system is decoupled from domain types (`Field` takes `String?`, not `FieldError?` — a deliberate, documented choice).
- **The `RepaymentInput` contract.** Making the calculator accept *only* a validated value type, with preconditions documented at the type, is exactly right.
- **Documentation density.** Every file carries a header explaining what it does and why. `KNOWN_ISSUES.md` documents a real defect with reproduction steps, the tests that pin it, three candidate fixes, and which one was chosen and why. This is better than most production codebases.

## 3.2 Validation runs three full projections per Calculate

[BeaconViewModel.calculate()](../Beacon/Features/PayoffPlanner/BeaconViewModel.swift#L106-L127) calls `revalidate()` (validation pass 1), then `InputValidator.buildInput(from:)`, which itself calls `validate(raw)` again ([InputValidator.swift:162](../Beacon/Domain/Validation/InputValidator.swift#L162)) — pass 2.

Each pass in `.byPayment` mode runs [`byPaymentTermAlert`](../Beacon/Domain/Validation/InputValidator.swift#L269-L306), a loop of **up to 360 iterations of `Decimal` arithmetic**. This also runs on every debounced keystroke.

Not a performance problem at current scale, but it is a correctness smell: the validator's job is to answer "is this valid," and it is answering it by *fully simulating the calculation*. Two engines now compute the same amortization with subtly different code, and they can drift apart.

**Recommended refactor.** Have `validate()` return the already-built `RepaymentInput` alongside the result (e.g. `ValidationResult.input: RepaymentInput?`), so a single pass serves both purposes. Longer term, have `byPaymentTermAlert` call the real calculator with a row cap rather than reimplementing the loop — one engine, one source of truth.

## 3.3 Dead code inventory

| Item | Location | Note |
|---|---|---|
| `Item.swift` | [Beacon/Item.swift](../Beacon/Item.swift) | Unused SwiftData template model — see §1.4 |
| `SummaryStatCard.swift` | [DesignSystem/Components/SummaryStatCard.swift](../Beacon/DesignSystem/Components/SummaryStatCard.swift) | **Empty file** — a header comment and `import SwiftUI`. The actual component is defined at the bottom of [SummaryRow.swift](../Beacon/Features/PayoffPlanner/Results/SummaryRow.swift#L93). Actively misleading: a developer opening the design system finds nothing. |
| `showRecalculateBar` | [BeaconViewModel.swift:68](../Beacon/Features/PayoffPlanner/BeaconViewModel.swift#L68) | The recalculate bar was removed in commit `605c105`; the property, and the tech spec §3.2/§3.3 sections describing it, remain |
| `BeaconMotion.subtleChange` | [BeaconDesignSystem.swift:168](../Beacon/DesignSystem/BeaconDesignSystem.swift#L168) | Defined and documented as unused-by-design; acceptable, but flag it |
| `Font.beaconHeroNumber` | [BeaconDesignSystem.swift:89](../Beacon/DesignSystem/BeaconDesignSystem.swift#L89) | Never applied — see §2.6 |
| `Field.textContentType` | [Field.swift:41](../Beacon/DesignSystem/Components/Field.swift#L41) | No call site passes it |
| `PrimaryButton.isLoading` | [PrimaryButton.swift](../Beacon/DesignSystem/Components/PrimaryButton.swift) | Effectively unreachable — see §1.1 |

**Decide `SummaryStatCard` deliberately.** Phase 3 results say *"if SummaryStatCard is needed elsewhere, move it to DesignSystem/Components/."* Someone created the destination file and never moved the code. Either move it or delete the stub.

## 3.4 Concurrency posture is a decision deferred

`SWIFT_VERSION = 5.0` with `SWIFT_APPROACHABLE_CONCURRENCY = YES`. The ViewModel is correctly `@MainActor`, and the domain layer is all value types, so the migration surface is genuinely small.

**Recommendation.** Turn on `SWIFT_STRICT_CONCURRENCY = complete` now, while the codebase is 2,400 lines and the fixes are trivial, rather than at 10,000 lines when they are not. Then move to Swift 6 language mode. Given the domain layer is pure `struct`s and the view layer is already main-actor-bound, I would expect a handful of `Sendable` annotations and little else.

While you are in build settings: `BeaconViewModel` uses Combine `Publishers.MergeMany` + `debounce` for what is, functionally, "recompute a derived value when inputs change." On iOS 17+, `@Observable` with a computed property expresses this in a fraction of the code and removes the debounce race in §2.8 by construction. Worth doing as part of the deployment-target decision in §1.5.

## 3.5 Localization is half-configured

`LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and `STRING_CATALOG_GENERATE_SYMBOLS` are set in the project, but **there is no `.xcstrings` file** and every user-facing string is a Swift literal. `"USD"` is hardcoded in six places.

Not a v1 blocker for a US-only launch, but the build settings are writing a check the code has not cashed. If international is ever plausible, adding the String Catalog now costs an afternoon; retrofitting it after v1.1 adds multi-currency costs considerably more.

---

# Part 4 — Engineering Infrastructure

This is the weakest area and the highest-leverage to fix, because every improvement in Parts 1–3 silently regresses without it.

## 4.1 There is no `.gitignore`

The repository has **no `.gitignore` file at all.** Nothing is protecting it except a global ignore file on this machine, which no collaborator, CI runner, or fresh clone will have.

Evidence it is already leaking: `Beacon.xcodeproj/xcuserdata/jayjones.xcuserdatad/xcschemes/xcschememanagement.plist` **is tracked**. That is personal Xcode UI state in version control. Six `.DS_Store` files are sitting untracked in the working tree, protected only by that global config.

**Fix immediately.**

```gitignore
.DS_Store
xcuserdata/
*.xcuserstate
build/
DerivedData/
.swiftpm/
*.xcresult
```

Then `git rm -r --cached Beacon.xcodeproj/xcuserdata`.

## 4.2 There is no CI

No `.github/`, no workflow files, no build or test automation of any kind. Every quality gate in this repository is currently "the author remembered."

**Fix.** A GitHub Actions workflow on push and PR that runs `xcodebuild test` against a pinned simulator. Roughly 25 lines. Add code coverage reporting (`-enableCodeCoverage YES`) and a coverage floor on `Domain/` so the calculator and validator cannot silently lose coverage.

## 4.3 There is no linter or formatter

No `.swiftlint.yml`, no `.swift-format`. The consequences are already visible as the indentation and spacing debris catalogued in §2.8, and — more importantly — the unused-variable and shadowed-binding issues in §2.4 that a linter would have flagged the day they were written.

**Fix.** Adopt **swift-format** (Apple's, now bundled with the toolchain — zero dependency cost) for formatting, and **SwiftLint** for the semantic rules that matter here: `unused_declaration`, `redundant_optional_initialization`, `force_unwrapping`, and a `file_length` cap. Run both in CI.

## 4.4 Test coverage is severely imbalanced

| Target | Tests | Assessment |
|---|---|---|
| `AmortizationCalculatorTests` (in [BeaconTests.swift](../BeaconTests/BeaconTests.swift)) | 17 | **Strong.** Leap-year February, 0% APR both modes, final-month adjustment, sum-of-principal identity, 360-month ceiling, date advancement. Genuinely good work. |
| [BeaconViewModelTests](../BeaconTests/BeaconViewModelTests.swift) | 12 | Reasonable coverage of state transitions |
| [InputValidatorTests](../BeaconTests/InputValidatorTests.swift) | **1** | **307 lines of validator, one test.** |
| [BeaconUITests](../BeaconUITests/BeaconUITests.swift) | 0 real | `testExample()` launches the app and asserts nothing. Pure Xcode template. |

**The validator gap is the serious one.** It is the layer standing between users and the empty-plan failure mode, and it is essentially untested. Specifically untested: every `parseDecimal` edge case (`"1,234.56"`, `"$1,234"`, `"1.2.3"`, `"abc"`, `"-500"`, leading/trailing whitespace, empty), APR boundary values (0, 100, 100.01, negative), months boundaries (0, 1, 360, 361), and the entire `byPaymentTermAlert` projection loop.

Also worth noting: the calculator test class is named `AmortizationCalculatorTests` but lives in a file called `BeaconTests.swift` — the generic template name. `KNOWN_ISSUES.md` refers to it by class name, so the file is hard to find. Rename it.

**Fix.**
1. Rename `BeaconTests.swift` → `AmortizationCalculatorTests.swift`.
2. Write ~20 validator tests, prioritizing `parseDecimal` and the boundary values above.
3. Replace the UI test stubs with three real end-to-end flows matching PRD §6: happy path, insufficient-payment recovery, and recalculation. These would have caught §1.1.
4. Add an `.xctestplan` so CI and Xcode run the same set.
5. **Adopt Swift Testing** (`import Testing`) for new tests. Parameterized cases via `@Test(arguments:)` are a natural fit for the boundary-value work above and will cut the line count substantially. Keep the existing XCTest suites — they interoperate — and migrate opportunistically.

## 4.5 Missing repository essentials

- **No `README.md`.** No build instructions, no architecture overview, no "run the tests like this." A new contributor's entry point is `scaffold.sh`, an initial-setup script that is now stale and should be deleted or moved to `Docs/`.
- **No `CLAUDE.md`.** Given how much of this codebase was built with AI assistance and how strong the design-system conventions are, a `CLAUDE.md` capturing the five design-system rules, the token-not-literal rule, and the domain-layer purity rule would materially improve consistency on future sessions.
- **No `LICENSE`.**
- **No `CONTRIBUTING.md` or PR template.** Lower priority for a solo project.
- **No dependency manifest.** Correct today — the app has zero third-party dependencies, which is a real asset. Worth stating explicitly in the README so it stays true.

---

# Part 5 — Accessibility

The tech spec makes specific accessibility commitments in §6.2. Some are met; two significant ones are not.

## ✅ Implemented well

- Every amortization row carries a structured `accessibilityLabel` reading *"Month N, January 2026, payment $X, interest $Y…"* exactly as specified ([AmortizationRowView](../Beacon/Features/PayoffPlanner/Results/AmortizationRowView.swift)), with the table header correctly `.accessibilityHidden(true)`.
- Errors are never signalled by color alone — every error and alert pairs an SF Symbol with text ([Field](../Beacon/DesignSystem/Components/Field.swift), [InlineNotice](../Beacon/DesignSystem/Components/InlineNotice.swift)). This satisfies the PRD's explicit requirement.
- `Field` provides `accessibilityLabel` + `accessibilityValue`, and prefixes error announcements with the field name.
- All tap targets are ≥44pt (`fieldHeight: 49`, `primaryButtonHeight: 49`).
- The legal disclaimer has an explicit label as specified.

## ❌ Gaps

**The chart is completely inaccessible.** [PayoffChartView](../Beacon/Features/PayoffPlanner/Results/PayoffChartView.swift) has no `accessibilityLabel`, no `AXChartDescriptor`, and no `.accessibilityElement` grouping. Tech spec §6.2 requires *"Chart has accessibilityLabel summarizing the payoff plan; individual data points accessible via SwiftUI Charts' built-in accessibility support."* Neither exists. A VoiceOver user swiping through the results hears unlabelled axis fragments and nothing about the payoff curve. This is the single largest accessibility gap and a spec violation, not just an omission.

*Fix:* add a summary label (*"Payoff curve. Balance falls from $5,000 in January 2026 to $0 in December 2027 over 24 months."*) and per-mark `.accessibilityLabel`/`.accessibilityValue` on the `LineMark`. Consider `AXChartDescriptorRepresentable` for full audio-graph support — it is roughly 40 lines and makes the chart genuinely usable.

**Dynamic Type will break the table.** [AmortizationRowView](../Beacon/Features/PayoffPlanner/Results/AmortizationRowView.swift) is a five-column `HStack` at `.footnote` (13pt) with `.minimumScaleFactor(0.7)` on the currency cells and a **fixed** `dateColumnWidth: 76`. At the larger accessibility text sizes, the currency cells shrink toward ~9pt while the fixed date column does not scale — producing a row that is simultaneously illegible and clipped.

*Fix:* use `@ScaledMetric` for `dateColumnWidth`, and switch to a stacked single-column row layout at `dynamicTypeSize >= .accessibility1`. A five-column financial table cannot survive accessibility sizes on a phone; a per-month card layout can.

**Related:** `Font.beaconHeroNumber` is a fixed 28pt that explicitly does not scale with Dynamic Type ("by design"). If §2.6 is resolved by *enabling* the hero treatment, wrap it in `@ScaledMetric` rather than shipping a non-scaling font.

**Also missing:** no Reduce Motion handling on `BeaconMotion.appearance` transitions, and no VoiceOver announcement when results appear after a calculation — a VoiceOver user taps Calculate and receives no confirmation that anything happened. `AccessibilityNotification.Announcement` on plan change would fix this in three lines and is a meaningful improvement.

---

# Part 6 — Documentation & Spec Drift

The documentation is a genuine strength — but it has drifted from the code, and stale docs are worse than no docs because they are trusted.

| Drift | Doc says | Code does |
|---|---|---|
| RecalculateBar | Tech spec §3.2, §3.3 and PRD Feature 1 specify a sticky recalculate bar with scroll-to-top | Removed in `605c105`; `showRecalculateBar` remains as dead code |
| Minimum iOS | PRD §8 and tech spec §1.1 both say **iOS 16** | App target 17.6; test targets 26.4 |
| Table columns | PRD §F3 specifies six columns including Month # | Five columns; deviation is well documented in the view header but not reflected in the PRD |
| Hero number | Usage guide and `SummaryRow` header describe the payoff date as the hero stat | `isHero: false` |
| Chart interaction | Tech spec §1.2 specifies `.chartOverlay` | Uses `.chartBackground` |
| Chart accessibility | Tech spec §6.2 requires a chart summary label | Not implemented |
| Axis labels | Phase 3 results describe responsive thresholds at 12 and 60 months | Hardcoded to 4 |
| Persistence | Tech spec §2.3: "no Core Data, no persistence layer" | `Item.swift` links SwiftData |

**Recommendation.** After the Part 1 and Part 2 fixes land, do a single documentation reconciliation pass: amend the PRD and tech spec to reflect the decisions actually made (removing the recalculate bar was a good call — record *why*), and add a short "Deviations from spec" section to `Docs/` so future readers know which document wins. `KNOWN_ISSUES.md` is the right model for this and should stay.

---

# Part 7 — Prioritized Remediation Plan

Sequenced so each stage protects the next.

### Stage 0 — Unblock the build *(half a day)*
1. Install the missing iOS platform / update Xcode so the project compiles (§1.5).
2. Resolve the deployment-target question and apply it to all four targets (§1.5).
3. Full clean build; fix every compiler warning — including the unused `balance` binding in §2.4.

### Stage 1 — Repository hygiene *(half a day, do before touching code)*
4. Add `.gitignore`; `git rm --cached` the tracked `xcuserdata` (§4.1).
5. Add `README.md` with build/test instructions and the zero-dependency claim (§4.5).
6. Add `swift-format` config and SwiftLint config; run once to normalize the whole tree in a single isolated commit so it never pollutes a review diff again (§4.3).
7. Add the GitHub Actions build-and-test workflow (§4.2).

### Stage 2 — Blocking defects *(one day)*
8. Fix `isCalculating` with `defer`; decide whether the loading state survives; fix the `.termExceedsMax` copy on the fallback path (§1.1).
9. Strip push/CloudKit entitlements and `UIBackgroundModes` (§1.2).
10. Delete `Item.swift` (§1.4).
11. Add the app icon; set `AccentColor` to sage (§1.3).
12. **Add a regression test for each of the above before fixing it.**

### Stage 3 — UX correctness *(two to three days)*
13. Touched-state validation gating (§2.1) — highest user-visible payoff in this plan.
14. Keyboard toolbar + `.scrollDismissesKeyboard` (§2.2).
15. Tooltip as `.overlay` to stop the layout jump (§2.3).
16. Chart tap cleanup; migrate to `.chartOverlay` or `.chartXSelection` (§2.4).
17. Resolve the hero-number decision (§2.6).
18. Unify formatting behind `BeaconFormatters` (§2.7).
19. Disclaimer to secondary text color (§2.8).

### Stage 4 — Test and accessibility hardening *(two to three days)*
20. Rename `BeaconTests.swift`; add ~20 validator tests via Swift Testing `@Test(arguments:)` (§4.4).
21. Three real UI test flows replacing the template stubs (§4.4).
22. Chart accessibility: summary label + `AXChartDescriptor` (§5).
23. Dynamic Type: `@ScaledMetric` date column + stacked row layout at accessibility sizes (§5).
24. VoiceOver announcement on results appearing; Reduce Motion handling (§5).
25. Full VoiceOver walkthrough on device — this is the Phase 4 item the tech spec already scheduled and it has not happened.

### Stage 5 — Code quality *(one to two days)*
26. Single-pass validation; `ValidationResult` carries the built input (§3.2).
27. Delete the remaining dead code; resolve `SummaryStatCard` (§3.3).
28. Enable `SWIFT_STRICT_CONCURRENCY = complete`, then Swift 6 language mode (§3.4).
29. Consider `@Observable` migration to replace the Combine pipeline (§3.4).
30. Documentation reconciliation pass (§6).

### Stage 6 — Launch prep
31. Instruments profiling at 360 rows on an older device — tech spec §1.2 Risk 3 specifies iPhone XR and it has not been done.
32. Privacy manifest (`PrivacyInfo.xcprivacy`) — now required for App Store submission; Beacon's is trivial since it collects nothing, which is a strong story to tell.
33. App Store listing, screenshots, privacy questionnaire.
34. TestFlight round.

**Estimated total: 8–11 working days to a submittable, well-tested v1.**

---

# Part 8 — Feature Enhancements (post-hygiene)

Sequenced by leverage against the PRD's own success metrics: a 4.5+ rating at 3 months, 40% second-session retention at 6 months, and organic growth from sharing at 12 months.

## Tier 1 — Ship in v1.1 *(directly serves stated metrics)*

**1. Share / export the payoff plan** — *already scoped in PRD §10; the highest-leverage feature available.*
It is the only v1.1 item that serves a job-to-be-done the PRD explicitly names ("give me something concrete I could show a partner, friend, or advisor") **and** the 1-year organic-growth metric. `PayoffPlan` was deliberately architected for this — tech spec §2 notes totals are computed eagerly "so v1.1 PDF export can serialize this struct directly with no recompute."
*Approach:* `ShareLink` with a SwiftUI `ImageRenderer` snapshot of the summary + chart for social sharing, and a `PDFDocument` export of the full table for the advisor use case. CSV export is a cheap third format that costs almost nothing once the export path exists.

**2. Session persistence** — *the direct enabler of the 40% return-visit metric.*
PRD §9 excludes persistence from v1, and the app currently forgets everything on launch — so a returning user must re-enter their balance, APR, and term from scratch. That is a hard tax on exactly the behavior the 6-month metric measures.
*Approach:* persist the last `RepaymentInput` only. Note the privacy tension — PRD §8 promises nothing is persisted — so this needs an explicit, visible user choice ("Remember my inputs"), Keychain rather than `UserDefaults` given the financial nature, and updated privacy copy. Tech spec §2.3 already anticipates preferences-only storage; balance and APR go beyond that and deserve the deliberate treatment.

**3. Payment-impact comparison ("what if I paid $50 more?")**
The most common question a user has *immediately after* seeing their plan, and the app currently cannot answer it without discarding the current plan. A single secondary row — *"Add $50/mo → paid off 7 months sooner, saves $412 in interest"* — converts a static calculator into a decision tool.
*Approach:* run the calculator two or three extra times with adjusted payments and show a compact delta row. The engine is already fast, pure, and side-effect-free, so this is nearly free. This is also the strongest candidate for the emotional-payoff job the PRD centers.

**4. Chart line animation on render** — *PRD §10, small effort, real delight.*
`.chartXScale` with an animated trim. The PRD is right that watching the line fall to zero reinforces the emotional payoff. Roughly a day, gated behind Reduce Motion.

## Tier 2 — v1.2 *(depth for engaged users)*

**5. Multiple cards with avalanche vs. snowball comparison.**
PRD §10 lists multiple-card support as the premium-tier candidate. The version worth building is not "several independent calculators" but the **strategy comparison** — showing that paying the highest-APR card first saves $X versus paying the smallest balance first is the single most valuable piece of advice a debt app can give, and no free calculator presents it well. This is a genuine premium hook.
*Architectural note:* `AmortizationCalculator` currently assumes one balance. Extending to a portfolio with an allocation strategy is a real redesign — worth planning as a deliberate v2 engine rather than a patch.

**6. Payoff milestones.** Mark "halfway paid off" and "interest crossover" (the month principal first exceeds interest) on the chart and in the table. Cheap to compute from existing rows, and directly serves the motivation job.

**7. Extra one-time payments.** "I'm getting a $2,000 bonus in March" — let the user drop lump sums into specific months and watch the curve shift. High emotional payoff; a moderate change to the engine's row loop.

**8. Interest-paid-to-date framing.** Total interest is currently one stat among three. Reframing it as *"You'll pay $1,847 to borrow $5,000 — 37% of what you owe"* is the sentence that changes behavior.

**9. iPad two-column layout.** PRD §10. Straightforward given `maxContentWidth` and the existing `ResultsView` split; genuinely better on a large screen.

## Tier 3 — Speculative, validate before building

**10. Payment reminders.** PRD §10. Cheap to build, but be honest that this shifts Beacon from a calculator to a habit app — a different retention model and a different support burden. The current entitlements already (accidentally) declare push; do it deliberately or not at all.

**11. Minimum-payment reality check.** Show what happens paying only the card's minimum versus the user's plan. Extremely persuasive, but requires modeling issuer minimum-payment formulas, which PRD §F2 explicitly excludes. Validate demand first.

**12. Financial-institution integration.** PRD §10 lists it. Plaid or equivalent brings compliance, cost, and a privacy story that directly contradicts Beacon's current strongest differentiator: *nothing leaves the device.* I would defer this indefinitely and consider "no account linking, ever" a marketing asset rather than a gap.

**13. Android.** PRD §10. Only after iOS retention validates the concept. If it happens, the pure-Swift domain layer is a good candidate for shared logic via Kotlin Multiplatform-style porting — the calculation engine has zero platform dependencies by design, which was smart.

## Explicitly recommend against

- **Ads or analytics SDKs.** Zero third-party dependencies and no data transmission is a real competitive asset in this category. If product analytics become necessary, prefer a privacy-preserving, self-hosted, or aggregate-only approach.
- **Accounts and login.** The app needs no server. Adding auth would create a data-breach surface for financial information the app currently never sees.
- **Gamification (streaks, badges).** Off-register for the "calm and trustworthy" brief that the design system deliberately enforces through restraint.

---

## Closing note

The foundation here is good enough that the remediation list reads longer than the situation warrants. The domain layer, the design system, and the documentation are all above the bar for a v1. What is missing is the connective tissue that keeps them that way — a `.gitignore`, a CI run, a linter, and a test suite that covers the validator as well as it covers the calculator — plus one state bug and a handful of template artifacts standing between this and the App Store.

Stages 0 through 2 are roughly two days of work and remove every hard blocker. Everything after that is quality compounding on a base that deserves it.

---

*Prepared 24 July 2026. Findings are from static review — the project could not be compiled locally (see §1.5), so no runtime or compiler verification was performed.*
