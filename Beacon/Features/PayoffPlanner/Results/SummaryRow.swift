//
//  SummaryRow.swift
//  Beacon
//
//  Three-stat row displayed above the chart and amortization table. Shows:
//    1. Payment (byMonths) or Total Months (byPayment) — left
//    2. Payoff date (center, hero — one per screen per usage guide)
//    3. Total interest paid (right)
//
//  Design decisions:
//    - Payoff date uses the hero treatment: beaconHeroNumber size in sage,
//      scaled via @ScaledMetric in SummaryStatCard
//    - Currency/date formatting via BeaconFormatters — no inline formatters
//

import SwiftUI

struct SummaryRow: View {

    let plan: PayoffPlan

    var body: some View {
        HStack(spacing: BeaconSpacing.lg) {

            if plan.input.mode == .byMonths {
                SummaryStatCard(
                    label: "Payment",
                    value: BeaconFormatters.currency(plan.rows.first?.payment ?? 0),
                    isMono: true
                )
            } else {
                SummaryStatCard(
                    label: "Total Months",
                    value: monthsValue(plan.rows.count),
                    isMono: true
                )
            }

            SummaryStatCard(
                label: "Payoff Date",
                value: BeaconFormatters.monthYear(plan.payoffDate),
                isMono: true,
                isHero: true
            )

            SummaryStatCard(
                label: "Total Interest",
                value: BeaconFormatters.currency(plan.totalInterestPaid),
                isMono: true
            )
        }
    }

    private func monthsValue(_ count: Int) -> String {
        count == 1 ? "1 month" : "\(count) mo"
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
