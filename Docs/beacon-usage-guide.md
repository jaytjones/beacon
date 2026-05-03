# Beacon Design System — Usage Guide

A short reference for using `BeaconDesignSystem.swift` consistently across the app. Read this once before writing your first view; reference it any time you reach for a new token.

---

## The five rules

1. **Reference tokens, never literals.** No hex values inside views. No `CGFloat(14)` for spacing. No `Font.system(size: 22)` calls. If a token doesn't exist for what you need, that's the conversation to have — not a workaround in the view file.
2. **Sage means progress.** It earns its place on the chart line, the payoff date stat, the $0 final amortization row, and primary action affordances (Calculate, Recalculate). Anywhere else, default to neutral. Sage on the segmented control's active segment, sage on chrome, sage as decoration — all wrong.
3. **Amber means attention.** It earns its place on inline alerts and validation errors. Don't use it for purely informational copy — that's the StaleResultsNotice's neutral variant.
4. **Native first.** Before building custom, audit: is there a SwiftUI primitive (`Picker`, `Menu`, `TextField`, `DatePicker`, `Toolbar`, `.safeAreaInset`, `.regularMaterial`) that does this? If yes, wrap it thinly. If no, build custom — and document the reason in the component file's header comment.
5. **Animate appearance, not change.** New content appearing for the first time gets `BeaconMotion.appearance` (250ms ease-out). Existing content changing values is instant. Always.

---

## Quick token reference

### Colors

| Token | Use for |
|---|---|
| `.beaconAccent` | Anything that signals progress — chart line, $0 row, primary buttons, sage stat |
| `.beaconAccentTint` | Sage-tinted backgrounds — final amortization row in v1 |
| `.beaconBackground` | The screen behind everything (white in light, true black in dark) |
| `.beaconSurface` | Card and surface fills (white in light, near-black `#1C1C1E` in dark) |
| `.beaconSurfaceAlt` | SummaryStatCard backgrounds, segmented control container, attention/info notice fills (with appropriate tint) |
| `.beaconRowAlt` | Alternating amortization table rows |
| `.beaconTextPrimary` / `Secondary` / `Tertiary` | Three text levels — never use SwiftUI's plain `.primary`/`.secondary` directly |
| `.beaconBorder` | 0.5px hairline borders on fields, cards, sticky bar |
| `.beaconAttention*` | Inline alerts and validation only — always paired with an SF Symbol |

### Typography

| Token | Where it goes |
|---|---|
| `.beaconHeroNumber` | One per screen — the payoff date stat. No other use. |
| `.beaconPageTitle` | "Your payoff plan" |
| `.beaconSectionTitle` | "Amortization" or any subsection header |
| `.beaconBody` / `.beaconBodyMono` | Default text / input values (use `Mono` for any numeric input) |
| `.beaconTableCell` | Amortization rows |
| `.beaconTableHeader` | Column headers — apply `.tracking(0.5).textCase(.uppercase)` at the usage site |
| `.beaconFieldLabel` | Form field labels above inputs |
| `.beaconButtonLabel` | Primary button text |
| `.beaconAlert` | Inline alerts, hints under fields, stale notice copy |
| `.beaconCaption` | Disclaimer footer, any fine print |

### Spacing

The canonical scale: `xs(4), sm(8), md(12), lg(16), xl(24), xxl(32), xxxl(48), huge(64)`. If you reach for a value not on the scale, the right answer is almost always to round to the nearest token. `BeaconSpacing.lg` is also the standard column gap inside the amortization table grid.

### Radius

Default to `BeaconRadius.md` (12pt) for fields, buttons, and cards. `sm` (8pt) for the segmented control. `lg` (16pt) only if a larger card or bottom sheet is introduced post-v1.

### Motion

Two named animations. `BeaconMotion.appearance` for first-time content reveal. `BeaconMotion.subtleChange` reserved for custom animations that need to match the segmented control's native ~150ms timing. Everything else is intentionally instant.

---

## The five most common mistakes

1. **Using SwiftUI's `.headline` font for headlines.** Apple's `.headline` is 17pt semibold; we want 17pt medium. Use `.beaconFieldLabel` for inline labels or `.beaconButtonLabel` for buttons. The names are role-based, not size-based, on purpose.

2. **Skipping `.monospacedDigit()` on currency.** All `.beaconBodyMono`, `.beaconHeroNumber`, and `.beaconTableCell` tokens already include it. If you're applying `.font(.body)` to a currency value somewhere, that's wrong — use `.beaconBodyMono`. Misaligned digit columns are the visual tell of a finance app that didn't ship its design.

3. **Animating value changes.** When recalculation updates the table and chart, do NOT wrap the change in `withAnimation`. Values just update. The brief is calm; calm doesn't dance.

4. **Sage where it doesn't belong.** Sage on the PillToggle's active segment? No — that uses `.beaconSurface` on a `.beaconSurfaceAlt` container. Sage as a decorative accent on a card border? No. Sage as an icon on a non-progress element? No. Sage's strict rule earns it the right to mean something.

5. **Hard-coding 0.5px borders.** Use `.beaconBorder` plus `.strokeBorder(_, lineWidth: 0.5)`. The 1.5px focused-field border is also an explicit usage-site value (no token needed — it's a narrow special case used only by `Field`).

---

## When nothing fits

In order of preference:

1. **Re-read the brief.** Most "I need a new token" moments are signals that the design is drifting from calm-and-restrained. Often the right answer is to remove a thing, not add one.
2. **Use the closest token.** If you genuinely think you need 14pt of spacing, round to 12 or 16. The system stays clean and the visual deficit is invisible.
3. **Propose, don't bypass.** If there's a real gap (e.g., v1.1 introduces a destructive delete action and we need a `.beaconDestructive` token), propose the addition with hex values, contrast checked, and one component using it. Don't add a one-off literal in a view file.

---

## Adding a new component

1. **Native audit first.** Document the answer in the component file's header comment, even if the answer is "no native equivalent."
2. **Use only the design system tokens.** No literals.
3. **Spec before coding.** Variants, states (default / focused / error / loading / disabled), props, accessibility labels, do/don't bullets. The exception is when the component is a thin wrapper around a native primitive — in which case the spec is mostly the wrapper rationale.
4. **Wire accessibility carefully.**
   - SF Symbol icons that accompany text alerts must be `.accessibilityHidden(true)` because the message text reads them aloud.
   - Tap targets ≥ 44pt per iOS HIG.
   - Color is never the sole signal for any error or status — always pair with icon + text.
5. **Add one line to this guide** noting the component's role.

---

## Native-first decisions, recorded

The following components in v1 lean fully or partially on native SwiftUI primitives. This list is here so future contributors don't reflexively rebuild what already works:

| Component | Native primitive | Notes |
|---|---|---|
| `Field` | `TextField` | Standard SwiftUI input with custom border + label layout |
| `PrimaryButton` | `Button` | Custom fill/loading state, otherwise native |
| `RepaymentModeSelector` | `Picker(.segmented)` | Fully native — no custom styling |
| `MenuField` | `Menu` | System handles popover; we style the closed trigger to match `Field` |
| `RecalculateBar` | `.safeAreaInset(edge: .top)` + `.regularMaterial` | Native sticky-with-blur pattern |
| `PayoffChartView` | SwiftUI Charts (iOS 16+) | Native chart, native `.chartOverlay` for tap |
| `DisclaimerFooter` | `Text` | Trivially native |
| Dynamic Type | All `.beacon*` font tokens that map to system styles scale automatically | `beaconHeroNumber` is the deliberate exception |

Custom-by-necessity (no native equivalent exists):

- `InlineNotice` (powering `InlineAlert` and `StaleResultsNotice`)
- `SummaryStatCard`
- `AmortizationRowView`
- `ChartTooltipOverlay`

---

*Beacon design system v1.0 — derived from the Beacon PRD v1.0 and Tech Spec v1.0 using the Design System Creation Guide (jaytjones/app-building-tools).*
