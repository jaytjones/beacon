//
//  ChartTooltipOverlay.swift
//  Beacon
//
//  Custom tooltip overlay rendered when a user taps a data point in
//  PayoffChartView. Shows the month, year, and remaining balance at that
//  point.
//
//  Design decisions:
//    - Uses InlineNotice-style chrome (rounded rect, subtle shadow, no color tint)
//    - Positioned near the top of the chart for maximum visibility
//    - Font and color tokens match the InlineNotice pattern
//    - No interaction — tap elsewhere on the chart to dismiss (handled by parent)
//
//  Phase 3 note: positioning logic could be enhanced to track the tapped
//  point's coordinate and position the tooltip closer to it. For v1, a
//  fixed top-center position is sufficient and keeps the code simpler.
//

import SwiftUI

struct ChartTooltipOverlay: View {

    let selectedRow: AmortizationRow

    var body: some View {
        VStack(alignment: .center, spacing: BeaconSpacing.sm) {

            // Month and year
            Text(monthYearText(selectedRow.date))
                .font(.beaconBodyMono)
                .foregroundStyle(Color.beaconTextPrimary)

            // Remaining balance
            Text(balanceText(selectedRow.remainingBalance))
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

    // MARK: - Formatting

    private func monthYearText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"  // "January 2026"
        return formatter.string(from: date)
    }

    private func balanceText(_ balance: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: balance).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: doubleValue)) ?? "$0.00"
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
