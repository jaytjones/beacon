//
//  AmortizationRowView.swift
//  Beacon
//
//  One row of the amortization table.
//
//  Five visible columns (deviation from PRD §F3 six-column spec): date,
//  payment, interest, principal, balance. Month # is dropped from the
//  visible row to fit comfortably on iPhone width — the column was the
//  least informative for sighted users since the date already conveys
//  position. monthNumber is preserved in the accessibility label so
//  VoiceOver users still hear "Month N, [date], ..." per tech spec §6.2.
//
//  Row backgrounds:
//   - Default: clear (table background shows through)
//   - Alternate: .beaconRowAlt — every other row for readability
//   - Final ($0 balance): .beaconAccentTint — sage tint marks payoff
//     per usage guide rule #2. Final-row tint takes priority over
//     alternation when both apply.
//
//  Currency cells use .minimumScaleFactor(0.7) so large balances
//  (e.g., "$50,234.56") shrink gracefully rather than truncating.
//

import SwiftUI

struct AmortizationRowView: View {

    let row: AmortizationRow
    var isAlternate: Bool = false
    var isFinalRow: Bool = false

    var body: some View {
        HStack(spacing: AmortizationTableMetrics.columnGap) {
            Text(displayDate)
                .lineLimit(1)
                .frame(width: AmortizationTableMetrics.dateColumnWidth, alignment: .leading)

            currencyCell(row.payment)
            currencyCell(row.interestPaid)
            currencyCell(row.principalPaid)
            currencyCell(row.remainingBalance)
        }
        .font(.beaconTableCell)
        .foregroundStyle(Color.beaconTextPrimary)
        .padding(.vertical, AmortizationTableMetrics.rowVerticalPadding)
        .padding(.horizontal, AmortizationTableMetrics.rowHorizontalPadding)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Cells

    private func currencyCell(_ amount: Decimal) -> some View {
        Text(amount.formatted(.currency(code: "USD")))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Derived state

    private var rowBackground: Color {
        if isFinalRow  { return .beaconAccentTint }
        if isAlternate { return .beaconRowAlt }
        return .clear
    }

    private var displayDate: String {
        row.date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var accessibilityLabel: String {
        let fullDate  = row.date.formatted(.dateTime.month(.wide).year())
        let payment   = row.payment.formatted(.currency(code: "USD"))
        let interest  = row.interestPaid.formatted(.currency(code: "USD"))
        let principal = row.principalPaid.formatted(.currency(code: "USD"))
        let balance   = row.remainingBalance.formatted(.currency(code: "USD"))
        return "Month \(row.monthNumber), \(fullDate), payment \(payment), interest \(interest), principal \(principal), balance \(balance)"
    }
}

/// Shared layout constants between AmortizationRowView and the parent
/// AmortizationTableView's header. Defined here because the row owns the
/// per-row layout; the header conforms to match.
enum AmortizationTableMetrics {
    /// Width of the leading date column. Sized to fit "Jan 2026" at .beaconTableCell.
    static let dateColumnWidth: CGFloat       = 76
    /// Gap between columns inside a row.
    static let columnGap: CGFloat             = BeaconSpacing.sm
    /// Vertical padding around the row content.
    static let rowVerticalPadding: CGFloat    = BeaconSpacing.sm
    /// Horizontal padding inside the row's outer edges.
    static let rowHorizontalPadding: CGFloat  = BeaconSpacing.lg
}

#Preview("States") {
    let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    return VStack(spacing: 0) {
        AmortizationRowView(
            row: AmortizationRow(id: 1, monthNumber: 1, date: date,
                payment: 234.56, interestPaid: 50.00, principalPaid: 184.56,
                remainingBalance: 4815.44)
        )
        AmortizationRowView(
            row: AmortizationRow(id: 2, monthNumber: 2, date: date,
                payment: 234.56, interestPaid: 48.15, principalPaid: 186.41,
                remainingBalance: 4629.03),
            isAlternate: true
        )
        AmortizationRowView(
            row: AmortizationRow(id: 24, monthNumber: 24, date: date,
                payment: 124.18, interestPaid: 1.24, principalPaid: 122.94,
                remainingBalance: 0),
            isFinalRow: true
        )
    }
}
