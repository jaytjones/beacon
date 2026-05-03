//
//  AmortizationCalculator.swift
//  Beacon
//
//  Pure Swift struct. Takes RepaymentInput, returns PayoffPlan.
//  Decimal arithmetic throughout per tech spec §5.
//

import Foundation

/// The pure-Swift calculation engine. No SwiftUI, no Combine, no ObservableObject.
///
/// Given a fully validated `RepaymentInput`, produces a complete `PayoffPlan`
/// with one `AmortizationRow` per calendar month until the balance reaches
/// exactly $0.00 (final-month adjustment per tech spec §5.2).
///
/// All arithmetic uses `Decimal` to avoid floating-point drift across 360 rows
/// (tech spec §5.5 rounding policy). Per-row `interestPaid` and
/// `remainingBalance` are rounded to 2 decimal places; intermediate values
/// like `dailyRate` are kept full-precision.
///
/// Preconditions (validated upstream by `InputValidator`):
///   - balance > 0
///   - apr in [0, 100]
///   - mode == .byMonths  → months != nil, months > 0
///   - mode == .byPayment → monthlyPayment != nil, payment > first-month interest
///   - projected term ≤ 360 months
///
/// If called with invalid input the calculator returns an empty plan rather
/// than crashing — but this path should never trigger in production.
struct AmortizationCalculator {

    /// Hard ceiling per PRD §11. Calculator returns an empty plan if exceeded.
    static let maxMonths = 360

    static func calculate(input: RepaymentInput) -> PayoffPlan {
        // Derive the monthly payment based on mode.
        let monthlyPayment: Decimal
        switch input.mode {
        case .byPayment:
            guard let p = input.monthlyPayment, p > 0 else {
                return emptyPlan(for: input)
            }
            monthlyPayment = p
        case .byMonths:
            guard let m = input.months, m > 0 else {
                return emptyPlan(for: input)
            }
            monthlyPayment = derivedMonthlyPayment(
                balance: input.balance,
                apr: input.apr,
                months: m
            )
        }

        // Daily periodic rate — kept full precision; never rounded.
        let dailyRate = input.apr / 100 / 365

        var rows: [AmortizationRow] = []
        var balance = input.balance
        var totalInterest: Decimal = 0
        var totalPaid: Decimal = 0

        var monthNumber = 1
        var currentDate = firstOfMonth(month: input.startMonth, year: input.startYear)

        while balance > 0 {
            // Safety valve — should be caught by validation, but never hang.
            if monthNumber > maxMonths {
                return emptyPlan(for: input)
            }

            let days = daysInMonth(currentDate)
            let rawInterest = dailyRate * Decimal(days) * balance
            let interest = round(rawInterest, scale: 2)

            let payment: Decimal
            let principal: Decimal
            let newBalance: Decimal

            // Final-month adjustment: if the regular payment would clear the
            // balance, set payment exactly equal to (balance + this month's
            // interest) so the row reads $0.00 with no overpayment.
            if balance + interest <= monthlyPayment {
                payment = round(balance + interest, scale: 2)
                principal = round(balance, scale: 2)
                newBalance = 0
            } else {
                payment = round(monthlyPayment, scale: 2)
                principal = payment - interest
                newBalance = round(balance - principal, scale: 2)
            }

            rows.append(AmortizationRow(
                id: monthNumber,
                monthNumber: monthNumber,
                date: currentDate,
                payment: payment,
                interestPaid: interest,
                principalPaid: principal,
                remainingBalance: newBalance
            ))

            totalInterest += interest
            totalPaid += payment
            balance = newBalance

            monthNumber += 1
            currentDate = advanceOneMonth(currentDate)
        }

        return PayoffPlan(
            input: input,
            rows: rows,
            totalInterestPaid: round(totalInterest, scale: 2),
            totalAmountPaid: round(totalPaid, scale: 2),
            payoffDate: rows.last?.date ?? firstOfMonth(month: input.startMonth, year: input.startYear)
        )
    }

    // MARK: - Helpers

    /// Standard amortization formula to derive monthly payment from a target term.
    /// Uses the monthly rate approximation `apr/12` (tech spec §5.2) — this is
    /// only used for payment derivation; per-row interest still uses the daily rate.
    ///
    /// Formula: P × (r(1+r)^n) / ((1+r)^n − 1)
    /// APR = 0% special case: payment = balance / months (no interest).
    static func derivedMonthlyPayment(balance: Decimal, apr: Decimal, months: Int) -> Decimal {
        guard months > 0 else { return 0 }
        guard apr > 0 else {
            // Zero-interest case: equal-share principal payments.
            return balance / Decimal(months)
        }

        // Decimal lacks pow(); use NSDecimalNumber bridge.
        let r = (apr / 100) / 12
        let onePlusR = NSDecimalNumber(decimal: 1 + r)
        let pow_n = onePlusR.raising(toPower: months)              // (1+r)^n

        let numerator   = NSDecimalNumber(decimal: r).multiplying(by: pow_n)
        let denominator = pow_n.subtracting(.one)
        let factor      = numerator.dividing(by: denominator)

        return NSDecimalNumber(decimal: balance).multiplying(by: factor).decimalValue
    }

    /// Round a Decimal to a fixed number of fractional digits using banker's-style
    /// `.plain` rounding (round-half-up) per tech spec §5.5.
    static func round(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    /// Number of days in the calendar month containing `date`.
    static func daysInMonth(_ date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// First day of the given calendar month/year, in the user's current calendar.
    static func firstOfMonth(month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Advance to the first of the following calendar month.
    static func advanceOneMonth(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
    }

    /// Defensive fallback when the calculator is misused. Validation should
    /// guarantee this path is never hit in production.
    private static func emptyPlan(for input: RepaymentInput) -> PayoffPlan {
        PayoffPlan(
            input: input,
            rows: [],
            totalInterestPaid: 0,
            totalAmountPaid: 0,
            payoffDate: firstOfMonth(month: input.startMonth, year: input.startYear)
        )
    }
}
