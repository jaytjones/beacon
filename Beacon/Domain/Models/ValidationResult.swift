//
//  ValidationResult.swift
//  Beacon
//
//  Synchronous validation output: errors, alert type, isValid.
//

import Foundation

/// Identifies which input field a validation error belongs to. Used by views
/// to render the error inline next to the offending field.
enum InputField: Equatable {
    case balance
    case apr
    case months
    case monthlyPayment
}

/// A field-level validation error. One per offending field per validation pass.
struct FieldError: Identifiable, Equatable {
    let id = UUID()
    let field: InputField
    let message: String

    // Custom Equatable so two errors are equal by (field, message), ignoring id.
    // Lets tests assert against expected errors without fabricating UUIDs.
    static func == (lhs: FieldError, rhs: FieldError) -> Bool {
        lhs.field == rhs.field && lhs.message == rhs.message
    }
}

/// The synchronous result of validating raw form input.
///
/// `isValid` is true when there are no field errors AND no alert. The
/// calculator should only ever be invoked with the fully-validated
/// `RepaymentInput` derived from a passing `ValidationResult`.
struct ValidationResult: Equatable {
    let isValid: Bool
    let fieldErrors: [FieldError]
    let alertType: AlertType?

    /// Convenience: a clean pass with no errors and no alert.
    static let valid = ValidationResult(isValid: true, fieldErrors: [], alertType: nil)
}
