//
//  BeaconRootView.swift
//  Beacon
//
//  Root container. Owns the BeaconViewModel as @StateObject. Composes the
//  page: page title → input form → (results when plan is ready) → disclaimer.
//
//  Phase 2.4 wires only the input form + amortization table. Deferred:
//    - SummaryRow                   (Phase 3)
//    - PayoffChartView              (Phase 3)
//    - StaleResultsNotice           (Phase 3 with RecalculateBar)
//    - RecalculateBar               (Phase 3)
//
//  Layout: AmortizationTableView is full-bleed by design. Horizontal padding
//  is applied selectively to the title, form, and disclaimer — NOT the
//  table. The .frame(maxWidth: BeaconLayout.maxContentWidth) cap centers
//  content on iPad per the usage guide; iPhone is below the cap so it has
//  no effect there.
//
//  Motion: results section uses BeaconMotion.appearance for first-time
//  reveal per usage guide §5 ("the three places this fires in v1: …
//  Results section reveal after the first calculation"). Modifier watches
//  `plan != nil` so updates to existing plans (Phase 3 recalculate flow)
//  won't re-animate — only the nil → non-nil transition triggers.
//

import SwiftUI

struct BeaconRootView: View {

    @StateObject private var viewModel = BeaconViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BeaconSpacing.xxl) {

                Text("Beacon")
                    .font(.beaconPageTitle)
                    .foregroundStyle(Color.beaconTextPrimary)
                    .padding(.horizontal, BeaconLayout.screenMargin)

                InputFormView(viewModel: viewModel)
                    .padding(.horizontal, BeaconLayout.screenMargin)

                if let plan = viewModel.plan {
                    AmortizationTableView(rows: plan.rows)
                        .transition(.opacity)
                }

                DisclaimerFooter()
                    .padding(.horizontal, BeaconLayout.screenMargin)
            }
            .frame(maxWidth: BeaconLayout.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BeaconSpacing.xxxl)
            .animation(BeaconMotion.appearance, value: viewModel.plan != nil)
        }
        .background(Color.beaconBackground)
    }
}

#Preview {
    BeaconRootView()
}
