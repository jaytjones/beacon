//
//  StartDatePicker.swift
//  Beacon
//
//  Start month + start year side-by-side. Two MenuField instances.
//  Year range is current year through current year + 10 per PRD §F1.
//

import SwiftUI

struct StartDatePicker: View {
    @Bindable var viewModel: BeaconViewModel

    var body: some View {
        HStack(alignment: .top, spacing: BeaconSpacing.md) {
            MenuField(
                label: "Month",
                selection: $viewModel.startMonth,
                options: Array(1...12),
                display: { Calendar.current.monthSymbols[$0 - 1] }
            )
            MenuField(
                label: "Year",
                selection: $viewModel.startYear,
                options: Array(currentYear...(currentYear + 10)),
                display: { String($0) }
            )
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
}
