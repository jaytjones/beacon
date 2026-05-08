//
//  ResultsView.swift
//  Beacon
//
//  Container view shown after the first successful calculation. Composes:
//    1. SummaryRow — Total interest, payoff date (hero), total months
//    2. PayoffChartView — Line graph with tap-to-tooltip
//    3. AmortizationTableView — Full month-by-month breakdown
//
//  Layout:
//    - SummaryRow: padded horizontally, full width
//    - Chart: padded horizontally, natural height
//    - Table: full-bleed (no padding — rows extend edge-to-edge)
//    - Spacing: lg between chart and table, xxl after table to disclaimer
//
//  This is inserted into BeaconRootView's main VStack when viewModel.plan != nil.
//  The parent (BeaconRootView) applies the BeaconMotion.appearance animation
//  when transitioning from no results to results (phase 2.4 + phase 3.0).
//

import SwiftUI

struct ResultsView: View {

    let plan: PayoffPlan

    var body: some View {
        VStack(alignment: .leading, spacing: BeaconSpacing.xl) {

            // Stats row
            SummaryRow(plan: plan)
                .padding(.horizontal, BeaconLayout.screenMargin)

            // Chart with tap-to-tooltip
            PayoffChartView(rows: plan.rows)
                .padding(.horizontal, BeaconLayout.screenMargin)

            // Full amortization table (full-bleed)
            AmortizationTableView(rows: plan.rows)
        }
    }
}

#Preview {
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

    return ScrollView {
        ResultsView(plan: plan)
    }
    .background(Color.beaconBackground)
}
