//
//  BeaconDesignSystem.swift
//  Beacon
//
//  Single source of truth for all design tokens. Reference these tokens —
//  never literal values — anywhere in views.
//
//  Sections:
//    1. Color helpers        (private)
//    2. Color tokens         (extension on Color)
//    3. Typography tokens    (extension on Font)
//    4. Spacing tokens       (BeaconSpacing)
//    5. Radius tokens        (BeaconRadius)
//    6. Layout tokens        (BeaconLayout)
//    7. Motion tokens        (BeaconMotion)
//

import SwiftUI
import UIKit

// MARK: - 1. Color helpers (private)

private extension Color {
    /// Initialize from a 24-bit hex literal: `Color(hex: 0x5C8A6F)`
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Light/dark dynamic color. Resolves at runtime per the user's appearance.
    init(light: Color, dark: Color) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - 2. Color tokens

extension Color {

    // Accent — sage. Reserved for "progress" semantics: chart line, payoff
    // date stat, $0 final amortization row, primary action affordances
    // (Calculate button, Recalculate bar). Never used for chrome or selection.
    static let beaconAccent     = Color(light: Color(hex: 0x5C8A6F), dark: Color(hex: 0x7BA88C))
    static let beaconAccentTint = Color(light: Color(hex: 0xE8F0EB), dark: Color(hex: 0x1E2820))

    // Surfaces. True black/white at the base — Apple Stocks pattern.
    // Cards step up to #1C1C1E in dark mode for a subtle elevation feel.
    static let beaconBackground = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x000000))
    static let beaconSurface    = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1C1C1E))
    static let beaconSurfaceAlt = Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x2C2C2E))
    static let beaconRowAlt     = Color(light: Color(hex: 0xF8F8FA), dark: Color(hex: 0x242426))

    // Text. `tertiary` deliberately fails WCAG AA for normal text — only use
    // it for hints, placeholders, and metadata the user doesn't need to read.
    // Use `primary` and `secondary` for everything that conveys meaning.
    static let beaconTextPrimary   = Color(light: Color(hex: 0x1C1C1E), dark: Color(hex: 0xFFFFFF))
    static let beaconTextSecondary = Color(light: Color(hex: 0x6B6B70), dark: Color(hex: 0xAEAEB2))
    static let beaconTextTertiary  = Color(light: Color(hex: 0x8E8E93), dark: Color(hex: 0x8E8E93))

    // Border. 0.5px hairline by default; 1.5px sage on focus (applied at the
    // usage site, no token needed for the focus variant).
    static let beaconBorder = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x38383A))

    // Attention — amber. The only chromatic color besides sage. Used for
    // inline alerts, validation errors, and any "this needs your attention"
    // signal. Always paired with an SF Symbol — color alone is never the
    // signal (accessibility requirement from the PRD).
    static let beaconAttention     = Color(light: Color(hex: 0xB7791F), dark: Color(hex: 0xE0A93B))
    static let beaconAttentionTint = Color(light: Color(hex: 0xFBF3E4), dark: Color(hex: 0x2E2615))
    static let beaconAttentionText = Color(light: Color(hex: 0x6B4A0F), dark: Color(hex: 0xE0A93B))

    // Reserved — not implemented in v1. Will hold the destructive red when
    // v1.1 introduces a delete or destructive action. Defining the slot now
    // documents the system's stance: red is for destruction only, never errors.
    // static let beaconDestructive = Color(light: ..., dark: ...)
}

// MARK: - 3. Typography tokens

extension Font {

    /// The hero number — used exactly once per screen, on the most
    /// emotionally resonant value (the payoff date in the SummaryStatCard).
    /// Custom size; does NOT scale with Dynamic Type — by design.
    static let beaconHeroNumber = Font
        .system(size: 28, weight: .semibold, design: .rounded)
        .monospacedDigit()

    // Page hierarchy — Dynamic Type-aware via Apple's semantic font styles.
    static let beaconPageTitle    = Font.title.weight(.semibold)        // 28pt
    static let beaconSectionTitle = Font.title2.weight(.semibold)       // 22pt

    // Body. `BodyMono` adds tabular numerals — use it for any input value
    // that displays a number, so digits don't shift width as the user types.
    static let beaconBody     = Font.body                               // 17pt regular
    static let beaconBodyMono = Font.body.monospacedDigit()             // 17pt regular tnum

    // Tables. Drops to 13pt to fit four currency columns at iPhone width.
    static let beaconTableCell   = Font.footnote.monospacedDigit()      // 13pt regular tnum
    static let beaconTableHeader = Font.caption2.weight(.medium)        // 11pt — apply
                                                                        // `.tracking(0.5).textCase(.uppercase)`
                                                                        // at the usage site

    // Form & controls
    static let beaconFieldLabel  = Font.footnote.weight(.medium)        // 13pt 500
    static let beaconButtonLabel = Font.headline.weight(.semibold)      // 17pt 600

    // Supporting type
    static let beaconAlert   = Font.footnote                            // 13pt — alerts, hints, stale notice
    static let beaconCaption = Font.caption2                            // 11pt — disclaimer footer
}

// MARK: - 4. Spacing tokens

enum BeaconSpacing {
    static let xs:   CGFloat = 4   // hint after input · icon → label · label → input
    static let sm:   CGFloat = 8   // chip padding · pill toggle internal · alert icon → text
    static let md:   CGFloat = 12  // input field padding · button vertical padding
    static let lg:   CGFloat = 16  // screen edge margin (iPhone) · card internal padding · column gap
    static let xl:   CGFloat = 24  // field → field · screen edge margin (iPad) · chart → table
    static let xxl:  CGFloat = 32  // form → results · table → disclaimer
    static let xxxl: CGFloat = 48  // top-of-screen pad · bottom safe area breathing room
    static let huge: CGFloat = 64  // page-level air (rare)
}

// MARK: - 5. Radius tokens

enum BeaconRadius {
    static let sm: CGFloat = 8     // pill toggle, segments
    static let md: CGFloat = 12    // fields, buttons, cards (default for everything)
    static let lg: CGFloat = 16    // larger cards or bottom sheets if introduced
}

// MARK: - 6. Layout tokens

enum BeaconLayout {
    static let screenMargin:        CGFloat = 16   // iPhone content edges
    static let screenMarginLarge:   CGFloat = 24   // iPad content edges
    static let maxContentWidth:     CGFloat = 600  // iPad content cap (centered)
    static let stickyBarHeight:     CGFloat = 44   // RecalculateBar — iOS HIG nav bar minimum
    static let primaryButtonHeight: CGFloat = 49   // 17pt body + 16pt vertical padding ×2
    static let fieldHeight:         CGFloat = 49   // matches button for visual rhythm
}

// MARK: - 7. Motion tokens

enum BeaconMotion {

    /// 250ms ease-out — used ONLY for new content appearing for the first time.
    ///
    /// The three places this fires in v1:
    ///   - RecalculateBar slide-in on first calculation
    ///   - StaleResultsNotice fade-in when inputs are edited post-calc
    ///   - Results section reveal after the first calculation
    ///
    /// Do not use this for value updates, focus transitions, or error
    /// appearance — those are intentionally instant.
    static let appearance: Animation = .easeOut(duration: 0.25)

    /// 150ms ease-out — subtle reactive transitions matching native segmented
    /// control timing. Reserved for custom animations that need to feel
    /// system-native. In v1, only `Picker(.segmented)` runs at this speed,
    /// and it does so natively without referencing this token.
    static let subtleChange: Animation = .easeOut(duration: 0.15)

    // Everything else is instant. The "calm and trustworthy" brief is
    // enforced by restraint, not motion.
}
