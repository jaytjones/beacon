//
//  AmortizationRow.swift
//  Beacon
//
//  One month of the payoff plan.
//

import Foundation

/// A single row of the amortization table — one calendar month in the payoff plan.
///
/// All `Decimal` values here are pre-rounded to 2 decimal places per the tech
/// spec rounding policy (§5.5). The calculator does the rounding; views format
/// for display only.
struct AmortizationRow: Identifiable, Equatable {
    let id: Int                  // == monthNumber
    let monthNumber: Int         // 1-based
    let date: Date               // first of the calendar month
    let payment: Decimal
    let interestPaid: Decimal
    let principalPaid: Decimal
    let remainingBalance: Decimal
}
