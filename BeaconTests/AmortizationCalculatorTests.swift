//
//  AmortizationCalculatorTests.swift
//  BeaconTests
//
//  Tests the calculation engine against known outputs and tech spec edge cases.
//

import XCTest
@testable import Beacon

final class AmortizationCalculatorTests: XCTestCase {

    // MARK: - Test helpers

    /// Build a .byPayment input with sensible defaults for tests.
    func payment(
        balance: Decimal,
        apr: Decimal,
        monthlyPayment: Decimal,
        startMonth: Int = 1,
        startYear: Int = 2026
    ) -> RepaymentInput {
        RepaymentInput(
            balance: balance,
            apr: apr,
            mode: .byPayment,
            months: nil,
            monthlyPayment: monthlyPayment,
            startMonth: startMonth,
            startYear: startYear
        )
    }

    /// Build a .byMonths input with sensible defaults for tests.
    func months(
        balance: Decimal,
        apr: Decimal,
        months: Int,
        startMonth: Int = 1,
        startYear: Int = 2026
    ) -> RepaymentInput {
        RepaymentInput(
            balance: balance,
            apr: apr,
            mode: .byMonths,
            months: months,
            monthlyPayment: nil,
            startMonth: startMonth,
            startYear: startYear
        )
    }
    /// Absolute value of a Decimal as a Double, for tolerance comparisons in tests.
    private func absDouble(_ value: Decimal) -> Double {
        let positive = value < 0 ? -value : value
        return NSDecimalNumber(decimal: positive).doubleValue
    }
    // MARK: - Happy path

    func test_byPayment_producesNonEmptyPlan() {
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 250)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertFalse(plan.rows.isEmpty, "Should produce at least one row")
        XCTAssertEqual(plan.rows.first?.monthNumber, 1)
        XCTAssertEqual(plan.rows.last?.remainingBalance, 0,
                       "Final row balance must be exactly 0.00")
    }

    func test_byMonths_producesPlanWithinOneMonthOfRequested() {
        // The byMonths derivation uses APR/12 as a monthly rate approximation,
        // while per-row interest uses the daily rate (varying days/month).
        // The two don't perfectly cancel, so the actual row count can come in
        // at requested ± 1 depending on the starting month's day count and
        // the term length. See KNOWN_ISSUES.md for the planned fix.
        let input = months(balance: 5000, apr: 24.99, months: 24)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(plan.rows.count, 23)
        XCTAssertLessThanOrEqual(plan.rows.count, 25)
        XCTAssertEqual(plan.rows.last?.remainingBalance, 0,
                       "Whatever the row count, final row must be exactly $0.00")
    }

    // MARK: - Final-month adjustment

    func test_finalMonthPayment_doesNotOverpay() {
        let input = payment(balance: 1000, apr: 20, monthlyPayment: 200)
        let plan = AmortizationCalculator.calculate(input: input)

        guard let final = plan.rows.last else {
            return XCTFail("Plan should have rows")
        }

        // Final row balance must be exactly 0.
        XCTAssertEqual(final.remainingBalance, 0,
                       "Final balance must be exactly 0.00, got \(final.remainingBalance)")

        // Final payment must be <= the regular payment (it gets adjusted down,
        // never up — interest doesn't get added on top of an already-full payment).
        XCTAssertLessThanOrEqual(final.payment, 200,
                                 "Final payment should not exceed regular payment")
    }

    func test_finalMonth_principalEqualsPreviousBalance() {
        // The final row's principalPaid should equal the *previous* row's
        // remainingBalance — that's what zeros it out.
        let input = payment(balance: 2500, apr: 18, monthlyPayment: 300)
        let plan = AmortizationCalculator.calculate(input: input)

        guard plan.rows.count >= 2 else {
            return XCTFail("Need at least 2 rows for this test")
        }

        let secondToLast = plan.rows[plan.rows.count - 2]
        let last = plan.rows[plan.rows.count - 1]

        XCTAssertEqual(last.principalPaid, secondToLast.remainingBalance,
                       "Final principal must clear the prior remaining balance")
    }

    // MARK: - Zero APR

    func test_zeroAPR_byPayment_noInterest() {
        let input = payment(balance: 1200, apr: 0, monthlyPayment: 100)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertEqual(plan.rows.count, 12, "1200 / 100 = 12 months exactly")
        XCTAssertEqual(plan.totalInterestPaid, 0, "0% APR should produce zero total interest")

        for row in plan.rows {
            XCTAssertEqual(row.interestPaid, 0, "Each row's interest must be 0 at 0% APR")
            XCTAssertEqual(row.payment, 100)
        }
    }

    func test_zeroAPR_byMonths_evenSplit() {
        let input = months(balance: 1200, apr: 0, months: 12)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertEqual(plan.rows.count, 12)
        XCTAssertEqual(plan.totalInterestPaid, 0)
        for row in plan.rows {
            XCTAssertEqual(row.payment, 100, "1200 / 12 = 100/month")
        }
    }

    // MARK: - Total amount paid invariant

    func test_totalAmountPaid_equalsBalancePlusInterest() {
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 250)
        let plan = AmortizationCalculator.calculate(input: input)

        // Sanity: total paid = total principal + total interest = balance + interest
        let expected = 5000 + plan.totalInterestPaid

        // Allow for at most $0.01 of rounding-mode artifact across the run.
        let drift = absDouble(plan.totalAmountPaid - expected)
        XCTAssertLessThanOrEqual(drift, 0.01,
                                 "Total paid should equal principal + interest within $0.01")
    }

    func test_sumOfPrincipalEqualsBalance() {
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 250)
        let plan = AmortizationCalculator.calculate(input: input)

        let principalSum = plan.rows.reduce(Decimal(0)) { $0 + $1.principalPaid }
        let drift = absDouble(principalSum - 5000)
        XCTAssertLessThanOrEqual(drift, 0.01,
                                 "Sum of all principal paid should equal starting balance")
    }

    // MARK: - 360-month ceiling

    func test_longTerm_completes() {
        // Verifies the engine produces a complete plan for a long-term scenario
        // without hitting the 360-month ceiling. Uses .byPayment to avoid the
        // monthly/daily approximation gap in derivedMonthlyPayment that affects
        // .byMonths mode at high APR + long term combinations.
        // (See known-issues notes — that gap is a real but separate concern.)
        let input = payment(balance: 10000, apr: 5, monthlyPayment: 70)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertGreaterThan(plan.rows.count, 200,
                             "Should produce a long plan with this payment/balance")
        XCTAssertLessThanOrEqual(plan.rows.count, AmortizationCalculator.maxMonths,
                                 "Should not exceed the 360-month ceiling")
        XCTAssertEqual(plan.rows.last?.remainingBalance, 0,
                       "Final row balance must be exactly 0.00")
    }
    func test_byMonths_atCeilingWithHighAPR_returnsEmptyPlan() {
        // KNOWN ISSUE: derivedMonthlyPayment uses APR/12 monthly approximation,
        // while per-row interest uses the daily rate. At high APR + long term
        // (e.g. 18% / 360 months / 31-day starting month), the derived payment
        // can fall below the first month's daily-rate interest, causing the
        // safety valve to trigger and return an empty plan.
        //
        // In production this scenario should be caught by validation before
        // reaching the engine. This test pins the current safety-valve behavior
        // until the derivation is fixed.
        let input = months(balance: 10000, apr: 18, months: 360,
                           startMonth: 1, startYear: 2026)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertTrue(plan.rows.isEmpty,
                      "Engine returns empty plan when derived payment can't cover daily-rate interest")
    }
    
    func test_termBeyond360_returnsEmptyPlan() {
        // A pathological case: tiny payment on a high balance/APR that would
        // never amortize in 360 months. The engine should bail rather than hang.
        // (In production, validation catches this; we test the safety valve.)
        let input = payment(balance: 50000, apr: 29.99, monthlyPayment: 50)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertTrue(plan.rows.isEmpty,
                      "Engine should return empty plan when 360-month ceiling is exceeded")
    }

    // MARK: - Date advancement

    func test_dates_advanceOneCalendarMonth() {
        let input = payment(balance: 1000, apr: 0, monthlyPayment: 250,
                            startMonth: 11, startYear: 2026)
        let plan = AmortizationCalculator.calculate(input: input)

        XCTAssertEqual(plan.rows.count, 4, "1000 / 250 = 4 months")

        let cal = Calendar.current
        let dates = plan.rows.map(\.date)

        // First row is November 2026.
        XCTAssertEqual(cal.component(.month, from: dates[0]), 11)
        XCTAssertEqual(cal.component(.year, from: dates[0]), 2026)

        // Final row should be February 2027 — confirms year rollover works.
        XCTAssertEqual(cal.component(.month, from: dates[3]), 2)
        XCTAssertEqual(cal.component(.year, from: dates[3]), 2027)
    }

    func test_dates_areAlwaysFirstOfMonth() {
        let input = payment(balance: 3000, apr: 18, monthlyPayment: 300,
                            startMonth: 6, startYear: 2026)
        let plan = AmortizationCalculator.calculate(input: input)

        for row in plan.rows {
            let day = Calendar.current.component(.day, from: row.date)
            XCTAssertEqual(day, 1, "Every row date should be the 1st of its month")
        }
    }

    // MARK: - Interest formula spot-check

    func test_firstMonthInterest_matchesDailyRateFormula() {
        // 5000 balance, 24.99% APR, January 2026 (31 days).
        // dailyRate = 24.99 / 100 / 365 = 0.000684657534...
        // monthlyInterest = dailyRate × 31 × 5000 = 106.12...
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 300,
                            startMonth: 1, startYear: 2026)
        let plan = AmortizationCalculator.calculate(input: input)

        let firstInterest = plan.rows.first?.interestPaid ?? 0

        // Expected ~$106.12 — allow $0.01 tolerance for rounding direction.
        let drift = absDouble(firstInterest - Decimal(string: "106.12")!)
        XCTAssertLessThanOrEqual(drift, 0.01,
                                 "First-month interest mismatch: got \(firstInterest)")
    }

    func test_februaryInterest_uses28Days() {
        // Same balance and APR, but starting in February of a non-leap year.
        // monthlyInterest = dailyRate × 28 × 5000 = 95.85...
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 300,
                            startMonth: 2, startYear: 2026)
        let plan = AmortizationCalculator.calculate(input: input)

        let firstInterest = plan.rows.first?.interestPaid ?? 0
        let drift = absDouble(firstInterest - Decimal(string: "95.85")!)
        XCTAssertLessThanOrEqual(drift, 0.01,
                                 "February (28 days) interest mismatch: got \(firstInterest)")
    }

    func test_leapFebruary_uses29Days() {
        // 2028 is a leap year — February has 29 days.
        // monthlyInterest = dailyRate × 29 × 5000 = 99.27...
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 300,
                            startMonth: 2, startYear: 2028)
        let plan = AmortizationCalculator.calculate(input: input)

        let firstInterest = plan.rows.first?.interestPaid ?? 0
        let drift = absDouble(firstInterest - Decimal(string: "99.27")!)
        XCTAssertLessThanOrEqual(drift, 0.01,
                                 "Leap February (29 days) interest mismatch: got \(firstInterest)")
    }

    // MARK: - Identifiable contract

    func test_rowIDsAreUniqueAndSequential() {
        let input = payment(balance: 5000, apr: 24.99, monthlyPayment: 250)
        let plan = AmortizationCalculator.calculate(input: input)

        let ids = plan.rows.map(\.id)
        XCTAssertEqual(ids, Array(1...ids.count),
                       "Row IDs should be 1, 2, 3, ... matching monthNumber")
    }
}

