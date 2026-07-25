//
//  ValidationResult.swift
//  Beacon
//
//  Synchronous validation output: errors, alert type, isValid, and the
//  pre-built RepaymentInput so callers never need a second parsing pass.
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
/// When `isValid == true`, `validatedInput` is non-nil and ready to pass
/// directly to the calculator — no second parsing pass needed.
struct ValidationResult {
    let isValid: Bool
    let fieldErrors: [FieldError]
    let alertType: AlertType?
    /// Non-nil exactly when `isValid == true`.
    let validatedInput: RepaymentInput?

    static let valid = ValidationResult(isValid: true, fieldErrors: [], alertType: nil, validatedInput: nil)
}

extension ValidationResult: Equatable {
    // Equality is determined by the validation outcome alone; validatedInput
    // is excluded so RepaymentInput doesn't need an Equatable conformance.
    static func == (lhs: ValidationResult, rhs: ValidationResult) -> Bool {
        lhs.isValid == rhs.isValid &&
        lhs.fieldErrors == rhs.fieldErrors &&
        lhs.alertType == rhs.alertType
    }
}
