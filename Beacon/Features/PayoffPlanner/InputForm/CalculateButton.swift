//
//  CalculateButton.swift
//  Beacon
//
//  Wraps PrimaryButton, wired to the ViewModel's calculate flow.
//  Disabled when !canCalculate; shows spinner while isCalculating.
//

import SwiftUI

struct CalculateButton: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        PrimaryButton(
            title: "Calculate",
            isLoading: viewModel.isCalculating,
            isEnabled: viewModel.canCalculate,
            action: { viewModel.calculate() }
        )
    }
}
