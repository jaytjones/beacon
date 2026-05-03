//
//  InlineNotice.swift
//  Beacon
//
//  Reusable inline notice surface. Powers InlineAlertView and StaleResultsNotice.
//
//  Native audit: no native primitive for inline notices. SwiftUI's `Alert` and
//  `.alert(...)` modifier present modal system alerts, which the PRD explicitly
//  rules out — Beacon's alerts and notices are inline. This is the inline
//  surface; specific call-sites (InlineAlertView, StaleResultsNotice) wrap it.
//
//  Two variants. The presence/absence of the icon is the primary signal:
//    - .attention: amber tint + exclamation-triangle icon. Validation errors
//      and inline alerts. Color is paired with the icon — never alone.
//    - .neutral:   alt-surface tint, no icon. Informational copy
//      (StaleResultsNotice). Absence of the icon is the affordance.
//

import SwiftUI

struct InlineNotice: View {

    enum Variant {
        case attention
        case neutral
    }

    let variant: Variant
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BeaconSpacing.sm) {
            if variant == .attention {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }
            Text(message)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .font(.beaconAlert)
        .foregroundStyle(textColor)
        .padding(BeaconSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                .fill(backgroundColor)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        switch variant {
        case .attention: return .beaconAttentionTint
        case .neutral:   return .beaconSurfaceAlt
        }
    }

    private var textColor: Color {
        switch variant {
        case .attention: return .beaconAttentionText
        case .neutral:   return .beaconTextSecondary
        }
    }

    private var accessibilityLabel: String {
        switch variant {
        case .attention: return "Alert: \(message)"
        case .neutral:   return message
        }
    }
}

#Preview("Variants") {
    VStack(alignment: .leading, spacing: BeaconSpacing.lg) {
        InlineNotice(
            variant: .attention,
            message: "Your payment doesn't cover the monthly interest. Try increasing it to at least $24.66."
        )

        InlineNotice(
            variant: .neutral,
            message: "Your inputs have changed — tap Calculate to update your plan."
        )
    }
    .padding(BeaconSpacing.lg)
}
