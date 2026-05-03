//
//  RepaymentModeSelector.swift
//  Beacon
//
//  Pill toggle for By months / By payment amount.
//
//  Native audit: fully native — `Picker(.segmented)`. The selection binding
//  routes through ViewModel.switchMode(to:) so flipping the toggle clears
//  the inactive field's value and validation error in one atomic update.
//

import SwiftUI

struct RepaymentModeSelector: View {
    @ObservedObject var viewModel: BeaconViewModel

    var body: some View {
        Picker("Repayment mode", selection: modeBinding) {
            ForEach(RepaymentMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Repayment mode")
    }

    private var modeBinding: Binding<RepaymentMode> {
        Binding(
            get: { viewModel.repaymentMode },
            set: { viewModel.switchMode(to: $0) }
        )
    }
}
