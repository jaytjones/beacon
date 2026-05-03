//
//  InputFormView.swift
//  Beacon
//
//  Composes the input form: balance, APR, repayment mode toggle, the
//  conditional months-or-payment field, start date, optional alert, and the
//  Calculate button. All children observe the same BeaconViewModel.
//
//  Field order matches PRD Flow 1. Spacing follows the design system's
//  "field → field" rhythm (BeaconSpacing.xl). The mode-driven field swap
//  and alert appearance are intentionally instant — per usage guide rule #5,
//  BeaconMotion.appearance is reserved for first-time content reveal events
//  (RecalculateBar, StaleResultsNotice, Results section), not these.
//

import SwiftUI

struct InputFormView: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BeaconSpacing.xl) {

            BalanceField(viewModel: viewModel)
            APRField(viewModel: viewModel)
            RepaymentModeSelector(viewModel: viewModel)

            switch viewModel.repaymentMode {
            case .byMonths:  MonthsField(viewModel: viewModel)
            case .byPayment: MonthlyPaymentField(viewModel: viewModel)
            }

            StartDatePicker(viewModel: viewModel)

            if let alertType = viewModel.alertType {
                InlineAlertView(alertType: alertType)
            }

            CalculateButton(viewModel: viewModel)
        }
    }
}
