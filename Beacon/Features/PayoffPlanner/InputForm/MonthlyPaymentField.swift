//
//  MonthlyPaymentField.swift
//  Beacon
//
//  Monthly payment input. Visible when RepaymentMode == .byPayment.
//

import SwiftUI

struct MonthlyPaymentField: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        Field(
            label: "Monthly payment",
            placeholder: "$0.00",
            text: $viewModel.monthlyPaymentText,
            keyboardType: .decimalPad,
            isMonospacedDigit: true,
            error: viewModel.error(for: .monthlyPayment)
        )
    }
}
