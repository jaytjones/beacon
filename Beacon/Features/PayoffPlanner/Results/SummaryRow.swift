//
//  SummaryRow.swift
//  Beacon
//
//  Three-stat row displayed above the chart and amortization table. Shows:
//    1. Total interest paid (left)
//    2. Payoff date (center, hero number — one per screen per usage guide)
//    3. Total months (right)
//
//  Design decisions:
//    - Uses SummaryStatCard component (three identical cards in a row)
//    - Payoff date uses .beaconHeroNumber (28pt semibold, reserved for this one
//      high-impact stat per design system rule #2: "Sage means progress")
//    - Total interest and months use .beaconBody for label + .beaconBodyMono
//      for value (currency and number values use monospacedDigit)
//    - Cards use .beaconSurfaceAlt background for subtle visual grouping
//    - Full-width row on iPhone; might compress on narrow screens — considered
//      but kept simple for v1
//
//  Tech spec reference: §3.2 component hierarchy; §4 state management
//  (payoffPlan contains totalInterestPaid, payoffDate, plus rows.count)
//

import SwiftUI

struct SummaryRow: View {

    let plan: PayoffPlan

    var body: some View {
        HStack(spacing: BeaconSpacing.lg) {

            // First cell: conditional based on repayment mode
            // - If user entered "by months" → show calculated Payment Amount
            // - If user entered "by payment amount" → show calculated Total Months
            if plan.input.mode == .byMonths {
                        SummaryStatCard(
                                label: "Payment",
                                value: currencyValue(plan.rows.first?.payment ?? 0),
                                isMono: true
                            )
                        } else {
                            SummaryStatCard(
                                label: "Total Months",
                                value: monthsValue(plan.rows.count),
                                isMono: true
                            )
                        }

                        // Payoff date (center — always shown)
                        SummaryStatCard(
                            label: "Payoff Date",
                            value: payoffDateValue(plan.payoffDate),
                            isMono: true,
                            isHero: false
                        )

                        // Total interest (right — always shown)
                        SummaryStatCard(
                            label: "Total Interest",
                            value: currencyValue(plan.totalInterestPaid),
                            isMono: true
                        )
        }
    }

    // MARK: - Formatting

    private func currencyValue(_ decimal: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: decimal).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: doubleValue)) ?? "$0.00"
    }

    private func payoffDateValue(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"  // "Jan 2026" (shorter)
            return formatter.string(from: date)
        }

    private func monthsValue(_ count: Int) -> String {
        count == 1 ? "1 month" : "\(count) mo"
    }
}

// MARK: - SummaryStatCard (design system component)

/// Reusable card for displaying a single stat: label + value. Three of these
/// appear side-by-side in SummaryRow. Can optionally render as the "hero"
/// card (payoff date with .beaconHeroNumber).
struct SummaryStatCard: View {

    let label: String
    let value: String
    let isMono: Bool
    let isHero: Bool

    init(
        label: String,
        value: String,
        isMono: Bool = false,
        isHero: Bool = false
    ) {
        self.label = label
        self.value = value
        self.isMono = isMono
        self.isHero = isHero
    }

    var body: some View {
        VStack(alignment: .center, spacing: BeaconSpacing.xs) {

            Text(label)
                .font(.beaconFieldLabel)
                .foregroundStyle(Color.beaconTextSecondary)
                .lineLimit(1)

            Text(value)
                            .font(isMono ? .beaconBodyMono : .beaconBody)
                .foregroundStyle(isHero ? Color.beaconAccent : Color.beaconTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)  // allow slight shrinking if needed
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BeaconSpacing.md)
        .padding(.horizontal, BeaconSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BeaconRadius.md)
                .fill(Color.beaconSurfaceAlt)
        )
    }
}

#Preview("Realistic payoff plan") {
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let payoffDate = Calendar.current.date(byAdding: .month, value: 24, to: start)!

    var rows: [AmortizationRow] = []
    var balance = Decimal(5000)
    let monthlyPayment = Decimal(234.56)

    for month in 1...24 {
        let date = Calendar.current.date(byAdding: .month, value: month - 1, to: start)!
        let interest = balance * Decimal(0.18) / 365 * Decimal(30)
        let principal = month == 24 ? balance : monthlyPayment - interest
        let newBalance = balance - principal
        balance = newBalance < 0 ? 0 : newBalance

        rows.append(AmortizationRow(
            id: month, monthNumber: month, date: date,
            payment: month == 24 ? balance + interest : monthlyPayment,
            interestPaid: interest,
            principalPaid: principal,
            remainingBalance: balance
        ))
    }

    let plan = PayoffPlan(
        input: RepaymentInput(
            balance: 5000,
            apr: 18,
            mode: .byPayment,
            months: nil,
            monthlyPayment: 234.56,
            startMonth: 1,
            startYear: 2026
        ),
        rows: rows,
        totalInterestPaid: Decimal(1234.56),
        totalAmountPaid: Decimal(6234.56),
        payoffDate: payoffDate
    )

    return VStack(spacing: BeaconSpacing.xl) {
        SummaryRow(plan: plan)
            .padding(.horizontal, BeaconSpacing.lg)

        Spacer()
    }
    .padding(.vertical, BeaconSpacing.lg)
    .background(Color.beaconBackground)
}

#Preview("Short total with large numbers") {
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let payoffDate = Calendar.current.date(byAdding: .month, value: 1, to: start)!

    let rows = [
        AmortizationRow(id: 1, monthNumber: 1, date: start,
            payment: 10000, interestPaid: 100, principalPaid: 9900,
            remainingBalance: 0)
    ]

    let plan = PayoffPlan(
        input: RepaymentInput(
            balance: 10000,
            apr: 12,
            mode: .byPayment,
            months: nil,
            monthlyPayment: 10000,
            startMonth: 1,
            startYear: 2026
        ),
        rows: rows,
        totalInterestPaid: Decimal(100),
        totalAmountPaid: Decimal(10100),
        payoffDate: payoffDate
    )

    return VStack(spacing: BeaconSpacing.xl) {
        SummaryRow(plan: plan)
            .padding(.horizontal, BeaconSpacing.lg)

        Spacer()
    }
    .padding(.vertical, BeaconSpacing.lg)
    .background(Color.beaconBackground)
}
