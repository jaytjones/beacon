//
//  ChartTooltipOverlay.swift
//  Beacon
//
//  Custom tooltip rendered as a floating overlay when a user taps a data
//  point in PayoffChartView. Shows the month, year, and remaining balance.
//
//  Positioned via .overlay(alignment: .top) on the Chart in PayoffChartView
//  so it floats without displacing layout.
//

import SwiftUI

struct ChartTooltipOverlay: View {

    let selectedRow: AmortizationRow

    var body: some View {
        VStack(alignment: .center, spacing: BeaconSpacing.sm) {

            Text(BeaconFormatters.monthYearLong(selectedRow.date))
                .font(.beaconBodyMono)
                .foregroundStyle(Color.beaconTextPrimary)

            Text(BeaconFormatters.currency(selectedRow.remainingBalance))
                .font(.beaconBodyMono)
                .foregroundStyle(Color.beaconTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BeaconSpacing.md)
        .padding(.horizontal, BeaconSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BeaconRadius.md)
                .fill(Color.beaconSurface)
                .stroke(Color.beaconBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, BeaconSpacing.lg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

#Preview {
    let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1))!
    let row = AmortizationRow(
        id: 6,
        monthNumber: 6,
        date: date,
        payment: 234.56,
        interestPaid: 100.00,
        principalPaid: 134.56,
        remainingBalance: 2500.50
    )

    return VStack(spacing: BeaconSpacing.xl) {
        ChartTooltipOverlay(selectedRow: row)

        Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.beaconBackground)
}
