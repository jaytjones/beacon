//
//  InputValidator.swift
//  Beacon
//
//  Validates raw form input strings, produces ValidationResult.
//

import Foundation

/// The validation layer between the form's raw text inputs and the calculator's
/// strongly-typed `RepaymentInput`. Pure Swift — no SwiftUI, no Combine.
///
/// Two responsibilities:
///   1. Parse and range-check each field, producing field-level errors for
///      anything that won't bind to the calculator's contract.
///   2. Detect business-logic conditions that should block calculation but
///      aren't field errors — `insufficientPayment` and `termExceedsMax`.
///      These surface as `AlertType` rather than `FieldError`.
///
/// Validation is synchronous and idempotent — call it as often as you like,
/// it just inspects and returns. The ViewModel decides when to call it.
struct InputValidator {

    /// All raw form fields, keyed by their `InputField` identity. The ViewModel
    /// holds these as `@Published String` properties; this struct is a
    /// value-type snapshot used for one validation pass.
    struct RawInputs: Equatable {
        var balance: String
        var apr: String
        var mode: RepaymentMode
        var months: String
        var monthlyPayment: String
        var startMonth: Int
        var startYear: Int
    }

    /// Validate raw inputs and produce a `ValidationResult`.
    ///
    /// If `isValid == true`, callers can safely build a `RepaymentInput` via
    /// `buildInput(from:)` and pass it to the calculator.
    static func validate(_ raw: RawInputs) -> ValidationResult {
        var errors: [FieldError] = []

        // 1. Balance — required, > 0
        let parsedBalance = parseDecimal(raw.balance)
        if raw.balance.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(FieldError(field: .balance,
                message: "Please enter a balance greater than $0"))
        } else if parsedBalance == nil {
            errors.append(FieldError(field: .balance,
                message: "Please enter a valid dollar amount"))
        } else if let b = parsedBalance, b <= 0 {
            errors.append(FieldError(field: .balance,
                message: "Please enter a balance greater than $0"))
        }

        // 2. APR — required, 0...100 (0% is valid per PRD §7)
        let parsedAPR = parseDecimal(raw.apr)
        if raw.apr.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(FieldError(field: .apr,
                message: "Please enter your APR"))
        } else if parsedAPR == nil {
            errors.append(FieldError(field: .apr,
                message: "Please enter numbers only"))
        } else if let a = parsedAPR, a < 0 || a > 100 {
            errors.append(FieldError(field: .apr,
                message: "Please enter a valid APR — most credit cards are between 15% and 30%"))
        }

        // 3. Mode-specific field
        var parsedMonths: Int? = nil
        var parsedPayment: Decimal? = nil

        switch raw.mode {
        case .byMonths:
            parsedMonths = parseInt(raw.months)
            if raw.months.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(FieldError(field: .months,
                    message: "Please enter a number of months"))
            } else if parsedMonths == nil {
                errors.append(FieldError(field: .months,
                    message: "Please enter numbers only"))
            } else if let m = parsedMonths, m < 1 {
                errors.append(FieldError(field: .months,
                    message: "Please enter a repayment term of at least 1 month"))
            } else if let m = parsedMonths, m > AmortizationCalculator.maxMonths {
                errors.append(FieldError(field: .months,
                    message: "Please enter a repayment term of 360 months or fewer"))
            } else if let feasibilityError = byMonthsFeasibilityError(
                balance: parsedBalance,
                apr: parsedAPR,
                months: parsedMonths,
                startMonth: raw.startMonth,
                startYear: raw.startYear
            ) {
                errors.append(feasibilityError)
            }

        case .byPayment:
            parsedPayment = parseDecimal(raw.monthlyPayment)
            if raw.monthlyPayment.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(FieldError(field: .monthlyPayment,
                    message: "Please enter a monthly payment"))
            } else if parsedPayment == nil {
                errors.append(FieldError(field: .monthlyPayment,
                    message: "Please enter a valid dollar amount"))
            } else if let p = parsedPayment, p <= 0 {
                errors.append(FieldError(field: .monthlyPayment,
                    message: "Please enter a monthly payment greater than $0"))
            }
        }

        // 4. Business-logic alerts — only checked if field-level parse succeeded.
        var alert: AlertType? = nil
        if errors.isEmpty,
           let balance = parsedBalance,
           let apr = parsedAPR {

            switch raw.mode {
            case .byPayment:
                if let payment = parsedPayment {
                    let firstMonthInterest = firstMonthInterestEstimate(
                        balance: balance,
                        apr: apr,
                        startMonth: raw.startMonth,
                        startYear: raw.startYear
                    )
                    if payment <= firstMonthInterest {
                        // Suggested minimum: first month's interest + $1, rounded up.
                        let minimum = AmortizationCalculator.round(
                            firstMonthInterest + 1, scale: 2
                        )
                        alert = .insufficientPayment(minimum: minimum)
                    }
                }

            case .byMonths:
                // byMonths uses field-level errors instead of alerts:
                //   - months > 360 caught at field level above
                //   - byMonths feasibility (KNOWN_ISSUES.md) caught at field level above
                break
            }
        }

        let isValid = errors.isEmpty && alert == nil
        return ValidationResult(isValid: isValid, fieldErrors: errors, alertType: alert)
    }

    /// Build a `RepaymentInput` from raw inputs that have already been
    /// validated. Returns nil if validation would fail — callers should
    /// always validate first.
    static func buildInput(from raw: RawInputs) -> RepaymentInput? {
        guard validate(raw).isValid,
              let balance = parseDecimal(raw.balance),
              let apr = parseDecimal(raw.apr) else {
            return nil
        }

        switch raw.mode {
        case .byMonths:
            guard let months = parseInt(raw.months) else { return nil }
            return RepaymentInput(
                balance: balance, apr: apr, mode: .byMonths,
                months: months, monthlyPayment: nil,
                startMonth: raw.startMonth, startYear: raw.startYear
            )
        case .byPayment:
            guard let payment = parseDecimal(raw.monthlyPayment) else { return nil }
            return RepaymentInput(
                balance: balance, apr: apr, mode: .byPayment,
                months: nil, monthlyPayment: payment,
                startMonth: raw.startMonth, startYear: raw.startYear
            )
        }
    }

    // MARK: - Helpers

    /// Parse a Decimal from a user-typed string, tolerating common formatting
    /// like commas and a leading dollar sign.
    static func parseDecimal(_ raw: String) -> Decimal? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    /// Parse an Int from a user-typed string.
    static func parseInt(_ raw: String) -> Int? {
        Int(raw.trimmingCharacters(in: .whitespaces))
    }

    /// Estimate first-month interest for the insufficient-payment check.
    /// Uses the same daily-rate × days-in-month × balance formula as the
    /// calculator (§5.2), so the alert threshold matches what the engine
    /// would actually compute.
    private static func firstMonthInterestEstimate(
        balance: Decimal,
        apr: Decimal,
        startMonth: Int,
        startYear: Int
    ) -> Decimal {
        let dailyRate = apr / 100 / 365
        let date = AmortizationCalculator.firstOfMonth(month: startMonth, year: startYear)
        let days = AmortizationCalculator.daysInMonth(date)
        let raw = dailyRate * Decimal(days) * balance
        return AmortizationCalculator.round(raw, scale: 2)
    }

    /// Detects the byMonths catastrophic case from KNOWN_ISSUES.md ("Calculator:
    /// `byMonths` mode payment derivation gap"): when the standard amortization
    /// formula's monthly-rate approximation produces a payment that doesn't
    /// cover the actual first-month interest (computed at daily rate × actual
    /// days in the user's start month), the calculator would loop until its
    /// `monthNumber > maxMonths` safety valve and return an empty plan.
    ///
    /// We catch the case here and surface a months-field error so the user gets
    /// a clear "try a longer term" message instead of an empty results pane.
    ///
    /// Returns nil if any input is missing/invalid (other field errors will
    /// already surface) or if the derivation is feasible.
    private static func byMonthsFeasibilityError(
        balance: Decimal?,
        apr: Decimal?,
        months: Int?,
        startMonth: Int,
        startYear: Int
    ) -> FieldError? {
        guard let balance, balance > 0,
              let apr, apr >= 0, apr <= 100,
              let months, months > 0, months <= AmortizationCalculator.maxMonths
        else { return nil }

        let derivedPayment = AmortizationCalculator.derivedMonthlyPayment(
            balance: balance,
            apr: apr,
            months: months
        )
        let firstMonthInterest = firstMonthInterestEstimate(
            balance: balance,
            apr: apr,
            startMonth: startMonth,
            startYear: startYear
        )

        guard derivedPayment <= firstMonthInterest else { return nil }

        return FieldError(
            field: .months,
            message: "At this APR, your balance won't be paid off in this many months. Try a longer term."
        )
    }
}
