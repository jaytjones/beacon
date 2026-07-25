//
//  CalculateButton.swift
//  Beacon
//
//  Wraps PrimaryButton, wired to the ViewModel's calculate flow.
//  Disabled when !canCalculate.
//

import SwiftUI

struct CalculateButton: View {
    var viewModel: BeaconViewModel

    var body: some View {
        PrimaryButton(
            title: "Calculate",
            isEnabled: viewModel.canCalculate,
            action: { viewModel.calculate() }
        )
    }
}
