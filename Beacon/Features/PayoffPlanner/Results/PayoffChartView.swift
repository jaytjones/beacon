//
//  PayoffChartView.swift
//  Beacon
//
//  SwiftUI Charts line graph of remaining balance over time.
//
//  Local state:
//    - `selectedRow` (AmortizationRow?): which row (if any) is selected for
//      tooltip display. Tap a point to set; tap elsewhere to clear.
//
//  Interaction:
//    - Tap on the chart → find the nearest row by date, show tooltip.
//    - Tap a second time → clear selection, tooltip dismisses.
//    - Tooltip floats as .overlay(alignment: .top) so it never displaces layout.
//
//  Design decisions:
//    - Line color: .beaconAccent (sage — reserved for "progress" per usage guide)
//    - Tap handler uses .chartOverlay so future PointMarks or area fills don't
//      intercept gestures
//    - X-axis label count scales with term length for readability
//

import SwiftUI
import Charts

struct PayoffChartView: View {

    let rows: [AmortizationRow]

    @State private var selectedRow: AmortizationRow?

    var body: some View {
        Chart {
            ForEach(rows, id: \.id) { row in
                LineMark(
                    x: .value("Date", row.date),
                    y: .value("Balance", NSDecimalNumber(decimal: row.remainingBalance).doubleValue)
                )
                .foregroundStyle(Color.beaconAccent)
                .interpolationMethod(.monotone)
            }

            if let selected = selectedRow {
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Balance", NSDecimalNumber(decimal: selected.remainingBalance).doubleValue)
                )
                .foregroundStyle(Color.beaconAccent)
                .symbolSize(100)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.beaconBorder)
                AxisTick(length: 4)
                    .foregroundStyle(Color.beaconTextSecondary)
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(BeaconFormatters.currencyWhole(doubleValue))
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
                    if let date = value.as(Date.self) {
                        Text(BeaconFormatters.monthYear(date))
                            .font(.beaconCaption)
                            .foregroundStyle(Color.beaconTextSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleChartTap(at: location, proxy: proxy)
                }
        }
        .overlay(alignment: .top) {
            if let selected = selectedRow {
                ChartTooltipOverlay(selectedRow: selected)
                    .padding(.top, BeaconSpacing.sm)
            }
        }
        .animation(BeaconMotion.subtleChange, value: selectedRow?.id)
        .frame(height: 200)
        .padding(.vertical, BeaconSpacing.md)
    }

    // MARK: - Tap handling

    private func handleChartTap(at location: CGPoint, proxy: ChartProxy) {
        guard let date = proxy.value(atX: location.x, as: Date.self) else {
            selectedRow = nil
            return
        }
        selectedRow = rows.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: - Axis label count

    /// Scale label density to term length: every month for short plans,
    /// sparser for longer ones so labels don't overlap.
    private var axisLabelCount: Int {
        let count = rows.count
        if count <= 12 { return count }
        if count <= 60 { return 6 }
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

#Preview("Long term (24 months)") {
    var rows: [AmortizationRow] = []
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    var balance = Decimal(5000)
    let monthlyPayment = Decimal(234.56)

    for month in 1...24 {
        let date = Calendar.current.date(byAdding: .month, value: month - 1, to: start)!
        let interest = balance * Decimal(0.18) / 365 * Decimal(30)
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
