//
//  StaleResultsNotice.swift
//  Beacon
//
//  Inline notice shown below the InputFormView when the user has edited any
//  field after generating a payoff plan. Disappears automatically when the
//  user taps Calculate and the plan updates.
//
//  Design decisions:
//    - Uses InlineNotice with .neutral variant (informational, not an error)
//    - Appears via BeaconMotion.appearance fade-in when inputs change
//    - Dismisses instantly when results update (no animation out per usage guide)
//    - Placed between form and results in BeaconRootView hierarchy
//
//  Tech spec reference: §6.1 edge cases; PRD §1 Feature 1
//  Phase 2 results: "Inline notice that appears below the form and above
//  the results when inputs are edited post-calculation" — deferred from
//  Phase 2, implemented in Phase 3 alongside RecalculateBar.
//

import SwiftUI

struct StaleResultsNotice: View {

    var body: some View {
        InlineNotice(
            variant: .neutral,
            message: "Your inputs have changed — tap Calculate to update your plan."
        )
    }
}

#Preview {
    VStack(spacing: BeaconSpacing.lg) {
        StaleResultsNotice()
            .padding(.horizontal, BeaconLayout.screenMargin)

        Spacer()
    }
    .padding(.vertical, BeaconSpacing.xl)
    .background(Color.beaconBackground)
}
