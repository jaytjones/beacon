//
//  MonthsField.swift
//  Beacon
//
//  Months input — integer-only repayment term. Visible when
//  RepaymentMode == .byMonths.
//

import SwiftUI

struct MonthsField: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        Field(
            label: "Months",
            placeholder: "12",
            text: $viewModel.monthsText,
            keyboardType: .numberPad,
            isMonospacedDigit: true,
            error: viewModel.error(for: .months),
            onFocusLost: { viewModel.markTouched(.months) }
        )
    }
}
