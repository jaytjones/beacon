//
//  InputValidatorTests.swift
//  BeaconTests
//
//  Tests for InputValidator — pin validator behavior independent of the
//  calculator and ViewModel layers. Uses Swift Testing for parametrized coverage
//  of parseDecimal edge cases, field boundary values, and business-logic alerts.
//

import Testing
import Foundation
@testable import Beacon

// MARK: - parseDecimal

@Suite("InputValidator.parseDecimal")
struct ParseDecimalTests {

    @Test("Returns nil for empty or whitespace-only strings", arguments: ["", "   ", "\t"])
    func emptyOrWhitespaceReturnsNil(_ raw: String) {
        #expect(InputValidator.parseDecimal(raw) == nil)
    }

    // Note: Decimal(string:) parses greedily — "12a34" returns 12, "1.2.3" returns 1.2.
    // Only strings that start with a non-parseable prefix return nil.
    @Test("Returns nil for strings with no leading numeric content",
          arguments: ["abc", "one hundred", "xyz"])
    func nonNumericReturnsNil(_ raw: String) {
        #expect(InputValidator.parseDecimal(raw) == nil)
    }

    @Test("Strips dollar sign prefix",
          arguments: zip(["$5000", "$1.50", "$0"], [Decimal(5000), Decimal(string: "1.50")!, Decimal(0)]))
    func stripsDollarSign(_ raw: String, _ expected: Decimal) {
        #expect(InputValidator.parseDecimal(raw) == expected)
    }

    @Test("Strips comma thousands separators",
          arguments: zip(["1,000", "10,000.50"], [Decimal(1000), Decimal(string: "10000.50")!]))
    func stripsCommas(_ raw: String, _ expected: Decimal) {
        #expect(InputValidator.parseDecimal(raw) == expected)
    }

    @Test("Strips dollar sign and commas together")
    func stripsDollarAndCommasTogether() {
        #expect(InputValidator.parseDecimal("$10,000.00") == Decimal(string: "10000.00")!)
    }

    @Test("Trims leading and trailing whitespace")
    func trimsWhitespace() {
        #expect(InputValidator.parseDecimal(" 500 ") == Decimal(500))
    }

    @Test("Parses zero correctly", arguments: ["0", "0.00", "$0"])
    func parsesZero(_ raw: String) {
        #expect(InputValidator.parseDecimal(raw) == Decimal(0))
    }

    @Test("Parses typical APR values",
          arguments: zip(["24.99", "0", "100"], [Decimal(string: "24.99")!, Decimal(0), Decimal(100)]))
    func parsesTypicalAPRs(_ raw: String, _ expected: Decimal) {
        #expect(InputValidator.parseDecimal(raw) == expected)
    }
}

// MARK: - Balance validation

@Suite("InputValidator — balance field")
struct BalanceValidationTests {

    private func raw(balance: String) -> InputValidator.RawInputs {
        InputValidator.RawInputs(
            balance: balance, apr: "24.99", mode: .byPayment,
            months: "", monthlyPayment: "300",
            startMonth: 1, startYear: 2026
        )
    }

    @Test("Invalid balances produce a balance field error",
          arguments: ["", "0", "-100", "abc", "-0.01"])
    func invalidBalanceProducesError(_ balance: String) {
        let result = InputValidator.validate(raw(balance: balance))
        #expect(result.fieldErrors.contains { $0.field == .balance })
    }

    @Test("Valid balances produce no balance field error",
          arguments: ["1", "5000", "$10,000.00", "0.01"])
    func validBalanceProducesNoError(_ balance: String) {
        let result = InputValidator.validate(raw(balance: balance))
        #expect(!result.fieldErrors.contains { $0.field == .balance })
    }
}

// MARK: - APR validation

@Suite("InputValidator — APR field")
struct APRValidationTests {

    private func raw(apr: String) -> InputValidator.RawInputs {
        InputValidator.RawInputs(
            balance: "5000", apr: apr, mode: .byPayment,
            months: "", monthlyPayment: "300",
            startMonth: 1, startYear: 2026
        )
    }

    @Test("Invalid APR values produce an APR field error",
          arguments: ["", "abc", "-1", "100.01", "200", "999"])
    func invalidAPRProducesError(_ apr: String) {
        let result = InputValidator.validate(raw(apr: apr))
        #expect(result.fieldErrors.contains { $0.field == .apr })
    }

    @Test("APR = 0 is valid per PRD §7")
    func zeroAPRIsValid() {
        let result = InputValidator.validate(raw(apr: "0"))
        #expect(!result.fieldErrors.contains { $0.field == .apr })
    }

    @Test("APR = 100 is valid (upper boundary)")
    func aprAt100IsValid() {
        let result = InputValidator.validate(raw(apr: "100"))
        #expect(!result.fieldErrors.contains { $0.field == .apr })
    }

    @Test("Typical APR values are valid", arguments: ["15", "24.99", "29.99", "5"])
    func typicalAPRsAreValid(_ apr: String) {
        let result = InputValidator.validate(raw(apr: apr))
        #expect(!result.fieldErrors.contains { $0.field == .apr })
    }
}

// MARK: - Months validation (byMonths mode)

@Suite("InputValidator — months field (byMonths mode)")
struct MonthsValidationTests {

    // June start (30 days) avoids the 31-day known-issue scenario
    private func raw(months: String) -> InputValidator.RawInputs {
        InputValidator.RawInputs(
            balance: "5000", apr: "18", mode: .byMonths,
            months: months, monthlyPayment: "",
            startMonth: 6, startYear: 2026
        )
    }

    @Test("Invalid months values produce a months field error",
          arguments: ["", "abc", "0", "361", "1000"])
    func invalidMonthsProducesError(_ months: String) {
        let result = InputValidator.validate(raw(months: months))
        #expect(result.fieldErrors.contains { $0.field == .months })
    }

    @Test("1 month is the minimum valid term")
    func oneMonthIsValid() {
        let result = InputValidator.validate(raw(months: "1"))
        #expect(!result.fieldErrors.contains { $0.field == .months })
    }

    @Test("Typical month values are valid", arguments: ["12", "24", "36", "60"])
    func typicalMonthsAreValid(_ months: String) {
        let result = InputValidator.validate(raw(months: months))
        #expect(!result.fieldErrors.contains { $0.field == .months })
    }
}

// MARK: - Monthly payment validation (byPayment mode)

@Suite("InputValidator — monthly payment field (byPayment mode)")
struct MonthlyPaymentValidationTests {

    private func raw(monthlyPayment: String) -> InputValidator.RawInputs {
        InputValidator.RawInputs(
            balance: "5000", apr: "18", mode: .byPayment,
            months: "", monthlyPayment: monthlyPayment,
            startMonth: 6, startYear: 2026
        )
    }

    @Test("Invalid payment values produce a monthly payment field error",
          arguments: ["", "0", "abc", "-50"])
    func invalidPaymentProducesError(_ monthlyPayment: String) {
        let result = InputValidator.validate(raw(monthlyPayment: monthlyPayment))
        #expect(result.fieldErrors.contains { $0.field == .monthlyPayment })
    }

    @Test("Valid payment amounts produce no field-level error",
          arguments: ["50", "200", "300", "$1,000"])
    func validPaymentProducesNoFieldError(_ monthlyPayment: String) {
        let result = InputValidator.validate(raw(monthlyPayment: monthlyPayment))
        #expect(!result.fieldErrors.contains { $0.field == .monthlyPayment })
    }
}

// MARK: - Business logic: alert types

@Suite("InputValidator — business logic alerts")
struct AlertValidationTests {

    @Test("Payment below first-month interest triggers insufficientPayment")
    func paymentBelowInterestTriggersAlert() {
        // $10,000 at 24.99% APR, January (31 days).
        // First-month interest ≈ $212. Payment of $10 is far below.
        let raw = InputValidator.RawInputs(
            balance: "10000", apr: "24.99", mode: .byPayment,
            months: "", monthlyPayment: "10",
            startMonth: 1, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        guard case .insufficientPayment(let minimum) = result.alertType else {
            Issue.record("Expected .insufficientPayment, got \(String(describing: result.alertType))")
            return
        }
        #expect(minimum > 10, "Suggested minimum must exceed user's $10 entry")
    }

    @Test("Payment clearly above first-month interest triggers no insufficientPayment")
    func paymentAboveInterestNoAlert() {
        // $1,000 at 18% APR, June (30 days). Interest ≈ $14.79. $200 easily clears it.
        let raw = InputValidator.RawInputs(
            balance: "1000", apr: "18", mode: .byPayment,
            months: "", monthlyPayment: "200",
            startMonth: 6, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        if case .insufficientPayment = result.alertType {
            Issue.record("$200 should clearly exceed first-month interest on $1,000 at 18% APR")
        }
    }

    @Test("Payment above first-month interest but unable to amortize in 360 months triggers termExceedsMax")
    func termExceedsMaxAlert() {
        // $10,000 at 3% APR, $30/month in January (31 days).
        // First-month interest = 3/100/365 × 31 × 10000 ≈ $25.48 — payment of $30 clears it.
        // But at ~$5/month principal reduction, payoff would take ~2,000 months >> 360.
        let raw = InputValidator.RawInputs(
            balance: "10000", apr: "3", mode: .byPayment,
            months: "", monthlyPayment: "30",
            startMonth: 1, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        #expect(result.alertType == .termExceedsMax)
    }

    @Test("Alert sets isValid to false with no field-level errors")
    func alertInvalidatesResultWithNoFieldErrors() {
        let raw = InputValidator.RawInputs(
            balance: "10000", apr: "24.99", mode: .byPayment,
            months: "", monthlyPayment: "10",
            startMonth: 1, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        #expect(result.isValid == false)
        #expect(result.fieldErrors.isEmpty, "Business-logic alerts should not generate field errors")
    }

    @Test("byMonths mode does not produce payment alerts")
    func byMonthsModeNoPaymentAlert() {
        let raw = InputValidator.RawInputs(
            balance: "5000", apr: "18", mode: .byMonths,
            months: "24", monthlyPayment: "",
            startMonth: 6, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        #expect(result.alertType == nil)
    }
}

// MARK: - byMonths feasibility (KNOWN_ISSUES.md)

@Suite("InputValidator — byMonths feasibility")
struct ByMonthsFeasibilityTests {

    @Test("High APR + 360 months + 31-day start surfaces a months field error")
    func highAPRAtCeilingWith31DayStartSurfacesMonthsError() {
        // Repro from KNOWN_ISSUES.md: derived monthly payment at APR/12 approximation
        // falls below actual first-month interest at 18% APR + 360 months + January start.
        let raw = InputValidator.RawInputs(
            balance: "10000", apr: "18", mode: .byMonths,
            months: "360", monthlyPayment: "",
            startMonth: 1, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        #expect(result.isValid == false)
        #expect(result.alertType == nil, "Feasibility failure must surface as a field error, not an alert")
        #expect(result.fieldErrors.contains { $0.field == .months })
    }

    @Test("Feasible byMonths input passes validation")
    func feasibleByMonthsInputPasses() {
        // June start (30 days) at 18% APR, 12 months — derived payment covers first-month interest.
        let raw = InputValidator.RawInputs(
            balance: "5000", apr: "18", mode: .byMonths,
            months: "12", monthlyPayment: "",
            startMonth: 6, startYear: 2026
        )
        let result = InputValidator.validate(raw)
        #expect(result.isValid)
        #expect(result.fieldErrors.isEmpty)
    }
}

// MARK: - buildInput

@Suite("InputValidator.buildInput")
struct BuildInputTests {

    @Test("Returns nil when balance is invalid")
    func returnsNilOnInvalidBalance() {
        let raw = InputValidator.RawInputs(
            balance: "", apr: "24.99", mode: .byPayment,
            months: "", monthlyPayment: "300",
            startMonth: 1, startYear: 2026
        )
        #expect(InputValidator.buildInput(from: raw) == nil)
    }

    @Test("Returns correct RepaymentInput for valid byPayment inputs")
    func buildsCorrectByPaymentInput() {
        let raw = InputValidator.RawInputs(
            balance: "5000", apr: "24.99", mode: .byPayment,
            months: "", monthlyPayment: "300",
            startMonth: 1, startYear: 2026
        )
        let input = InputValidator.buildInput(from: raw)
        #expect(input != nil)
        #expect(input?.balance == Decimal(5000))
        #expect(input?.apr == Decimal(string: "24.99")!)
        #expect(input?.mode == .byPayment)
        #expect(input?.monthlyPayment == Decimal(300))
        #expect(input?.months == nil)
    }

    @Test("Returns correct RepaymentInput for valid byMonths inputs")
    func buildsCorrectByMonthsInput() {
        let raw = InputValidator.RawInputs(
            balance: "5000", apr: "18", mode: .byMonths,
            months: "24", monthlyPayment: "",
            startMonth: 6, startYear: 2026
        )
        let input = InputValidator.buildInput(from: raw)
        #expect(input != nil)
        #expect(input?.months == 24)
        #expect(input?.mode == .byMonths)
        #expect(input?.monthlyPayment == nil)
    }

    @Test("Dollar sign and commas in balance are parsed correctly by buildInput")
    func buildInputHandlesFormattedBalance() {
        let raw = InputValidator.RawInputs(
            balance: "$5,000", apr: "18", mode: .byPayment,
            months: "", monthlyPayment: "200",
            startMonth: 6, startYear: 2026
        )
        let input = InputValidator.buildInput(from: raw)
        #expect(input?.balance == Decimal(5000))
    }
}
