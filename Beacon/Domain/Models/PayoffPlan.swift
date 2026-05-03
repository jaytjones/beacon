//
//  PayoffPlan.swift
//  Beacon
//
//  Complete output of a calculation run.
//

import Foundation

/// The complete output of an `AmortizationCalculator.calculate(input:)` call.
///
/// All derived totals (`totalInterestPaid`, `totalAmountPaid`, `payoffDate`) are
/// computed eagerly at calculation time per the tech spec — no lazy evaluation —
/// so v1.1 PDF export can serialize this struct directly with no recompute.
struct PayoffPlan: Equatable {
    let input: RepaymentInput
    let rows: [AmortizationRow]
    let totalInterestPaid: Decimal
    let totalAmountPaid: Decimal
    let payoffDate: Date         // date of the final row
}
