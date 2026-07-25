//
//  AmortizationTableView.swift
//  Beacon
//
//  Renders the full amortization table for a payoff plan: header row +
//  N AmortizationRowView instances inside a LazyVStack.
//
//  Per tech spec §3.3, this is a LazyVStack (not a SwiftUI List) inside
//  the parent ScrollView. Rows are only instantiated as they scroll into
//  view, keeping 360-row tables performant on older A-series chips.
//
//  Layout: full-bleed. Rows extend edge-to-edge so alternating row
//  backgrounds reach the screen edges. Parents must NOT wrap this view
//  in additional horizontal padding — internal row padding
//  (AmortizationTableMetrics.rowHorizontalPadding) provides the content
//  margin.
//
//  Header is .accessibilityHidden(true) — each row carries its own
//  structured label per tech spec §6.2.
//

import SwiftUI

struct AmortizationTableView: View {

    let rows: [AmortizationRow]

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var scaledDateWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !typeSize.isAccessibilitySize {
                header
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    AmortizationRowView(
                        row: row,
                        isAlternate: !index.isMultiple(of: 2),
                        isFinalRow: index == rows.count - 1
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AmortizationTableMetrics.columnGap) {
            headerLabel("Date")
                .frame(width: scaledDateWidth, alignment: .leading)
            headerLabel("Payment")
                .frame(maxWidth: .infinity, alignment: .trailing)
            headerLabel("Interest")
                .frame(maxWidth: .infinity, alignment: .trailing)
            headerLabel("Principal")
                .frame(maxWidth: .infinity, alignment: .trailing)
            headerLabel("Balance")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, AmortizationTableMetrics.rowVerticalPadding)
        .padding(.horizontal, AmortizationTableMetrics.rowHorizontalPadding)
        .accessibilityHidden(true)
    }

    private func headerLabel(_ text: String) -> some View {
        Text(text)
            .font(.beaconTableHeader)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.beaconTextSecondary)
            .lineLimit(1)
    }
}

#Preview("Short table") {
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let m2    = Calendar.current.date(byAdding: .month, value: 1, to: start)!
    let m3    = Calendar.current.date(byAdding: .month, value: 2, to: start)!

    return AmortizationTableView(rows: [
        AmortizationRow(id: 1, monthNumber: 1, date: start,
            payment: 234.56, interestPaid: 50.00, principalPaid: 184.56,
            remainingBalance: 415.44),
        AmortizationRow(id: 2, monthNumber: 2, date: m2,
            payment: 234.56, interestPaid: 4.15, principalPaid: 230.41,
            remainingBalance: 185.03),
        AmortizationRow(id: 3, monthNumber: 3, date: m3,
            payment: 186.88, interestPaid: 1.85, principalPaid: 185.03,
            remainingBalance: 0)
    ])
}
