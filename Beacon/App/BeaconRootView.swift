//
//  BeaconRootView.swift
//  Beacon
//
//  Root container. Owns the BeaconViewModel as @StateObject. Composes the
//  page: page title → input form → stale notice (if needed) → results (if plan exists) → disclaimer.
//
//  Phase 2.4 completed: input form + amortization table
//  Phase 3.0 completed:
//    - SummaryRow (with payoff date as hero number)
//    - PayoffChartView (with tap-to-tooltip via ChartTooltipOverlay)
//    - ResultsView (container for summary + chart + table)
//    - StaleResultsNotice (shown when inputs change post-calc)
//    - RecalculateBar (sticky bar with smooth scroll-to-top)
//
//  Layout:
//    - AmortizationTableView (in ResultsView) is full-bleed by design
//    - Horizontal padding applied selectively to title, form, stale notice, disclaimer
//    - .frame(maxWidth: BeaconLayout.maxContentWidth) centers content on iPad
//
//  Motion:
//    - Results section: BeaconMotion.appearance fade-in on first calculation
//    - RecalculateBar: BeaconMotion.appearance slide-in when showRecalculateBar = true
//    - StaleResultsNotice: BeaconMotion.appearance fade-in when hasStaleResults = true
//    - All other state changes (field edits, value updates) are instant per usage guide
//
//  Scroll-to-top:
//    - ScrollViewReader wraps the ScrollView to enable programmatic scrolling
//    - InputFormView anchored with .id("inputForm") at the top
//    - RecalculateBar's onTap closure scrolls to that anchor with smooth animation
//

import SwiftUI

struct BeaconRootView: View {

    @StateObject private var viewModel = BeaconViewModel()

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BeaconSpacing.xxl) {

                    Text("Beacon")
                        .font(.beaconPageTitle)
                        .foregroundStyle(Color.beaconTextPrimary)
                        .padding(.horizontal, BeaconLayout.screenMargin)

                    InputFormView(viewModel: viewModel)
                        .padding(.horizontal, BeaconLayout.screenMargin)
                        .id("inputForm")

                    // Stale results notice — shown when inputs edited but BEFORE first recalc
                    // (RecalculateBar takes over once it appears)
                    if viewModel.hasStaleResults {
                                            StaleResultsNotice()
                            .padding(.horizontal, BeaconLayout.screenMargin)
                            .transition(.opacity)
                            .animation(BeaconMotion.appearance, value: viewModel.hasStaleResults)
                    }

                    // Results section — appears on first calc, updates on recalc
                    if let plan = viewModel.plan {
                        ResultsView(plan: plan)
                            .transition(.opacity)
                            .animation(BeaconMotion.appearance, value: viewModel.plan != nil)
                    }

                    DisclaimerFooter()
                        .padding(.horizontal, BeaconLayout.screenMargin)
                }
                .frame(maxWidth: BeaconLayout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BeaconSpacing.xxxl)
            }
            .background(Color.beaconBackground)
            // Sticky RecalculateBar at top (Phase 3)
            // removed recalculate bar to clean up UX

        }
    }
}

#Preview {
    BeaconRootView()
}
