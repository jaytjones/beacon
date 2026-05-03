//
//  PrimaryButton.swift
//  Beacon
//
//  Primary action button. Native Button with custom sage fill, label, and
//  loading state. Used by Calculate and Recalculate per the usage guide
//  rule on sage-as-progress-affordance.
//
//  Native audit: thin wrapper around `Button` for native gesture handling
//  and accessibility. The wrapper adds:
//    - Sage fill at .beaconAccent
//    - White button label (no token — see exception below)
//    - Loading state holding the title footprint with a centered ProgressView
//    - 0.4 opacity on disabled (system-standard, no token — see exception below)
//
//  Two usage-site literal exceptions, parallel to Field's focused-border:
//    - .white text on sage fill: there is no "on-accent text" token in v1
//    - 0.4 disabled opacity: matches iOS HIG standard disabled treatment
//  Both are candidates for tokenization if they recur elsewhere.
//

import SwiftUI

struct PrimaryButton: View {

    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Hold the title's footprint so the button doesn't resize when loading
                Text(title)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .font(.beaconButtonLabel)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: BeaconLayout.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                    .fill(Color.beaconAccent)
            )
            .opacity(isInteractive ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }

    private var isInteractive: Bool { isEnabled && !isLoading }
}

#Preview("States") {
    VStack(spacing: BeaconSpacing.lg) {
        PrimaryButton(title: "Calculate", action: {})
        PrimaryButton(title: "Calculate", isEnabled: false, action: {})
        PrimaryButton(title: "Calculate", isLoading: true, action: {})
    }
    .padding(BeaconSpacing.lg)
}
