//
//  APRField.swift
//  Beacon
//
//  APR input — wraps Field with percentage-input configuration.
//  Placeholder copy is taken verbatim from PRD §F1 to prevent the
//  "decimal vs percentage" entry error (e.g. 0.24 instead of 24).
//

import SwiftUI

struct APRField: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        Field(
            label: "APR",
            placeholder: "e.g. 24.99 for 24.99% APR",
            text: $viewModel.aprText,
            keyboardType: .decimalPad,
            isMonospacedDigit: true,
            error: viewModel.error(for: .apr),
            onFocusLost: { viewModel.markTouched(.apr) }
        )
    }
}
