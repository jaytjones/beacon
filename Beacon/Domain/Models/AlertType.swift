//
//  AlertType.swift
//  Beacon
//
//  Enum distinguishing insufficientPayment and termExceedsMax alert conditions.
//

import Foundation

/// The two inline alert conditions that block calculation.
///
/// Both are detected during validation, before the calculator runs. The
/// calculator itself asserts these conditions are not present.
enum AlertType: Equatable {
    /// Monthly payment is ≤ the first month's interest charge — balance would
    /// never decrease. Associated value is the suggested minimum payment.
    case insufficientPayment(minimum: Decimal)

    /// Projected term exceeds the 360-month ceiling.
    case termExceedsMax
}
