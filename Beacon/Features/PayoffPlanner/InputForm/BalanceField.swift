//
//  BalanceField.swift
//  Beacon
//
//  Balance input — wraps Field with currency-input configuration.
//

import SwiftUI

struct BalanceField: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        Field(
            label: "Balance",
            placeholder: "$0.00",
            text: $viewModel.balanceText,
            keyboardType: .decimalPad,
            isMonospacedDigit: true,
            error: viewModel.error(for: .balance)
        )
    }
}
