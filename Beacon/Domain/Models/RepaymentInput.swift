//
//  RepaymentInput.swift
//  Beacon
//
//  Validated user input snapshot. Passed to AmortizationCalculator.
//

import Foundation

/// A validated snapshot of the user's form input at the moment a calculation runs.
///
/// This is produced by `InputValidator` from raw form strings and is the only
/// thing `AmortizationCalculator` accepts as input — the calculator never sees
/// raw text. By the time you hold a `RepaymentInput`, all preconditions are met:
/// balance > 0, apr in [0, 100], and exactly one of `months` / `monthlyPayment`
/// is non-nil based on `mode`.
struct RepaymentInput: Equatable {
    let balance: Decimal
    let apr: Decimal             // stored as percentage, e.g. 24.99 for 24.99% APR
    let mode: RepaymentMode
    let months: Int?             // non-nil iff mode == .byMonths
    let monthlyPayment: Decimal? // non-nil iff mode == .byPayment
    let startMonth: Int          // 1–12
    let startYear: Int
}
