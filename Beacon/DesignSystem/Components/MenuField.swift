//
//  MenuField.swift
//  Beacon
//
//  Dropdown selector. Wraps SwiftUI Menu with a Field-styled trigger so the
//  start-date row visually rhymes with the input fields above it.
//
//  Native audit: thin wrapper around `Menu`. The system handles popover
//  presentation, scrolling for long lists, and dismissal. The wrapper styles
//  the closed trigger to match Field's chrome (height, radius, border, label).
//
//  Generic over the underlying value type so a single component drives both
//  the start-month (Int 1–12) and start-year (Int + range) dropdowns.
//

import SwiftUI

struct MenuField<Value: Hashable>: View {

    let label: String
    @Binding var selection: Value
    let options: [Value]
    let display: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: BeaconSpacing.xs) {

            Text(label)
                .font(.beaconFieldLabel)
                .foregroundStyle(Color.beaconTextSecondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(display(option), systemImage: "checkmark")
                        } else {
                            Text(display(option))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(display(selection))
                        .font(.beaconBody)
                        .foregroundStyle(Color.beaconTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.beaconBody)
                        .imageScale(.small)
                        .foregroundStyle(Color.beaconTextTertiary)
                        .accessibilityHidden(true)
                }
                .frame(height: BeaconLayout.fieldHeight)
                .padding(.horizontal, BeaconSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                        .fill(Color.beaconSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                        .strokeBorder(Color.beaconBorder, lineWidth: 0.5)
                )
            }
            .accessibilityLabel(label)
            .accessibilityValue(display(selection))
        }
    }
}

#Preview("Start date") {
    @Previewable @State var month: Int = 5
    @Previewable @State var year: Int = 2026

    return HStack(spacing: BeaconSpacing.lg) {
        MenuField(
            label: "Month",
            selection: $month,
            options: Array(1...12),
            display: { Calendar.current.monthSymbols[$0 - 1] }
        )
        MenuField(
            label: "Year",
            selection: $year,
            options: Array(2026...2036),
            display: { String($0) }
        )
    }
    .padding(BeaconSpacing.lg)
}
