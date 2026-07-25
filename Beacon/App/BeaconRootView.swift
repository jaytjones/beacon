//
//  BeaconRootView.swift
//  Beacon
//
//  Root container. Owns the BeaconViewModel as @StateObject. Composes the
//  page: page title → input form → stale notice (if needed) → results (if
//  plan exists) → disclaimer.
//
//  Layout:
//    - Horizontal padding applied selectively to title, form, stale notice,
//      disclaimer
//    - .frame(maxWidth: BeaconLayout.maxContentWidth) centers content on iPad
//    - AmortizationTableView (in ResultsView) is padded to maxContentWidth;
//      it does not go full-bleed
//
//  Motion:
//    - Results section: BeaconMotion.appearance fade-in on first calculation
//    - StaleResultsNotice: BeaconMotion.appearance fade-in when hasStaleResults
//    - All other state changes are instant per usage guide
//

import SwiftUI
import Accessibility

struct BeaconRootView: View {

    @State private var viewModel = BeaconViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BeaconSpacing.xxl) {

                Text("Beacon")
                    .font(.beaconPageTitle)
                    .foregroundStyle(Color.beaconTextPrimary)
                    .padding(.horizontal, BeaconLayout.screenMargin)

                InputFormView(viewModel: viewModel)
                    .padding(.horizontal, BeaconLayout.screenMargin)
                    .id("inputForm")

                if viewModel.hasStaleResults {
                    StaleResultsNotice()
                        .padding(.horizontal, BeaconLayout.screenMargin)
                        .transition(.opacity)
                        .animation(reduceMotion ? nil : BeaconMotion.appearance, value: viewModel.hasStaleResults)
                }

                if let plan = viewModel.plan {
                    ResultsView(plan: plan)
                        .transition(.opacity)
                        .animation(reduceMotion ? nil : BeaconMotion.appearance, value: viewModel.plan != nil)
                }

                DisclaimerFooter()
                    .padding(.horizontal, BeaconLayout.screenMargin)
            }
            .frame(maxWidth: BeaconLayout.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BeaconSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.beaconBackground)
        .onChange(of: viewModel.plan?.payoffDate) { _, _ in
            guard let plan = viewModel.plan else { return }
            let months = plan.rows.count
            let interest = plan.totalInterestPaid.formatted(.currency(code: "USD"))
            let payoff = plan.payoffDate.formatted(.dateTime.month(.wide).year())
            AccessibilityNotification.Announcement(
                "Payoff plan ready. \(months) months. Total interest \(interest). Payoff date \(payoff)."
            ).post()
        }
    }
}

#Preview {
    BeaconRootView()
}
