//
//  InputFormView.swift
//  Beacon
//
//  Composes the input form: balance, APR, repayment mode toggle, the
//  conditional months-or-payment field, start date, optional alert, and the
//  Calculate button. All children observe the same BeaconViewModel.
//
//  A keyboard toolbar with a Done button is attached here so it appears
//  for all numeric fields in the form. The parent ScrollView's
//  .scrollDismissesKeyboard(.interactively) handles swipe-to-dismiss.
//

import SwiftUI
import UIKit

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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.medium)
            }
        }
    }
}
