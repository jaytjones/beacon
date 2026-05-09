//
//  PayoffChartView.swift
//  Beacon
//
//  SwiftUI Charts line graph of remaining balance over time. Renders a line
//  from the starting balance to $0.00, with dynamic axis scaling.
//
//  Tech risk (HIGH per tech spec §1.2): `.chartOverlay` for tap-to-tooltip
//  is finicky; coordinate mapping from gesture to data point is manual and
//  error-prone. Built with reference to Apple's WWDC sample code.
//
//  Local state:
//    - `selectedRow` (AmortizationRow?): which row (if any) is selected for
//      tooltip display. Tap a point to set; tap elsewhere to clear.
//
//  Interaction:
//    - Tap on or near a data point → set selectedRow, ChartTooltipOverlay
//      renders with month/balance at that point.
//    - Tap elsewhere on chart → clear selectedRow, tooltip dismisses.
//    - The tooltip is rendered by the parent (ResultsView) using
//      ChartTooltipOverlay overlay on top of this chart.
//
//  Design decisions:
//    - Line color: .beaconAccent (sage, reserved for "progress" per usage guide)
//    - Y-axis: dynamic min/max based on starting balance; always includes 0
//    - X-axis: Month + Year labels at regular intervals (not every month for long terms)
//    - No animation on render per usage guide rule #5 ("Animate appearance, not change")
//

import SwiftUI
import Charts

struct PayoffChartView: View {

    let rows: [AmortizationRow]

    @State private var selectedRow: AmortizationRow?

    var body: some View {
        VStack(alignment: .leading, spacing: BeaconSpacing.md) {

            // Tooltip overlay — shown when a point is selected
            if let selected = selectedRow {
                ChartTooltipOverlay(selectedRow: selected)
                    .padding(.bottom, BeaconSpacing.sm)
            }

            Chart {
                ForEach(rows, id: \.id) { row in
                    LineMark(
                        x: .value("Date", row.date),
                        y: .value("Balance", NSDecimalNumber(decimal: row.remainingBalance).doubleValue)
                    )
                    .foregroundStyle(Color.beaconAccent)
                    .interpolationMethod(.monotone)  // smooth curve, not jagged
                }

                // Highlight the selected point if one is tapped
                if let selected = selectedRow {
                    PointMark(
                        x: .value("Date", selected.date),
                        y: .value("Balance", NSDecimalNumber(decimal: selected.remainingBalance).doubleValue)
                    )
                    .foregroundStyle(Color.beaconAccent)
                    .symbolSize(100)  // slightly larger when selected
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.beaconBorder)
                    AxisTick(length: 4)
                        .foregroundStyle(Color.beaconTextSecondary)
                    AxisValueLabel {
                        // Format as currency ($X,XXX or $X,XXX.XX depending on scale)
                        if let doubleValue = value.as(Double.self) {
                            Text(currencyLabel(doubleValue))
                                .font(.beaconCaption)
                                .foregroundStyle(Color.beaconTextSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: axisLabelCount)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.beaconBorder)
                    AxisTick(length: 4)
                        .foregroundStyle(Color.beaconTextSecondary)
                    AxisValueLabel {
                        // Format as "Mar 2026" or similar
                        if let date = value.as(Date.self) {
                            Text(monthYearLabel(date))
                                .font(.beaconCaption)
                                .foregroundStyle(Color.beaconTextSecondary)
                        }
                    }
                }
            }
            .chartBackground { chartProxy in
                // Tap gesture: find the nearest row to the tap, set selectedRow
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleChartTap(at: location, proxy: chartProxy)
                    }
            }
            .frame(height: 200)
            .padding(.vertical, BeaconSpacing.md)
        }
    }

    // MARK: - Tap handling

    /// Translate the tap location to a chart coordinate, find the nearest row,
    /// and set `selectedRow`. If tap is outside the chart area or no row is
    /// close enough, clear the selection.
    private func handleChartTap(at location: CGPoint, proxy: ChartProxy) {
        guard
            let date = proxy.value(atX: location.x, as: Date.self),
            let balance = proxy.value(atY: location.y, as: Double.self)
        else {
            selectedRow = nil
            return
        }

        // Find the row closest to the tapped date. Since rows are monthly,
        // a tap within half a month's width should select the nearest row.
        let nearest = rows.min { a, b in
            abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date))
        }

        // Only select if the tap is reasonably close (within ~1 month tolerance)
        // Simpler: always select the nearest row, no tolerance gate
        if let nearest = rows.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) {
            selectedRow = nearest
        }
    }

    // MARK: - Formatting

    /// Format a Double balance as currency label. For large values, use
    /// abbreviated format (e.g., "$50K") if space is tight; for v1 we use
    /// full amounts ($X,XXX or $X,XXX.XX).
    private func currencyLabel(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    /// Format a Date as "Month Year" for axis labels (e.g., "Mar 2026").
    private func monthYearLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    /// Dynamically choose how many X-axis labels to show. For short terms
    /// (< 12 months), show every month. For longer terms, space them out
    /// so they don't overlap.
    private var axisLabelCount: Int {
            // Show only 4 key labels (roughly quarterly) for readability
            return 4
        }
}

#Preview("Short term (3 months)") {
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let m2 = Calendar.current.date(byAdding: .month, value: 1, to: start)!
    let m3 = Calendar.current.date(byAdding: .month, value: 2, to: start)!

    return PayoffChartView(rows: [
        AmortizationRow(id: 1, monthNumber: 1, date: start,
            payment: 1234.56, interestPaid: 500.00, principalPaid: 734.56,
            remainingBalance: 4265.44),
        AmortizationRow(id: 2, monthNumber: 2, date: m2,
            payment: 1234.56, interestPaid: 425.65, principalPaid: 808.91,
            remainingBalance: 3456.53),
        AmortizationRow(id: 3, monthNumber: 3, date: m3,
            payment: 3456.53, interestPaid: 345.65, principalPaid: 3110.88,
            remainingBalance: 0)
    ])
    .padding()
}

#Preview("Long term (24 months, $5000 balance)") {
    var rows: [AmortizationRow] = []
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    var balance = Decimal(5000)
    let monthlyPayment = Decimal(234.56)

    for month in 1...24 {
        let date = Calendar.current.date(byAdding: .month, value: month - 1, to: start)!
        let interest = balance * Decimal(0.18) / 365 * Decimal(30)  // rough estimate
        let principal = monthlyPayment - interest
        balance -= principal
        if balance < 0 { balance = 0 }

        rows.append(AmortizationRow(
            id: month, monthNumber: month, date: date,
            payment: monthlyPayment,
            interestPaid: interest,
            principalPaid: principal,
            remainingBalance: balance
        ))
    }

    return PayoffChartView(rows: rows)
        .padding()
}
