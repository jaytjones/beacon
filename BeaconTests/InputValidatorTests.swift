//
//  InputValidatorTests.swift
//  Beacon
//
//  Created by Jay Jones on 5/3/26.
//


//
//  InputValidatorTests.swift
//  BeaconTests
//
//  Tests for InputValidator — pin validator behavior independent of the
//  calculator and ViewModel layers.
//

import XCTest
@testable import Beacon

final class InputValidatorTests: XCTestCase {

    /// Repro from `KNOWN_ISSUES.md` — "Calculator: `byMonths` mode payment
    /// derivation gap". At high APR + 360 months + 31-day start, the
    /// derived monthly payment falls below the actual first-month interest
    /// charge, so the calculator's row loop never amortizes and trips its
    /// safety valve. The validator catches the case first and returns a
    /// months-field error so the user sees a clear message instead of an
    /// empty results pane.
    func test_byMonths_atCeilingWithHighAPR_surfacesMonthsFieldError() {
        let raw = InputValidator.RawInputs(
            balance: "10000",
            apr: "18",
            mode: .byMonths,
            months: "360",
            monthlyPayment: "",
            startMonth: 1,    // January — 31 days, the catastrophic case
            startYear: 2026
        )

        let result = InputValidator.validate(raw)

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.alertType, "feasibility surfaces as a field error, not an alert")
        XCTAssertTrue(
            result.fieldErrors.contains { $0.field == .months },
            "expected a months-field error for the byMonths catastrophic case"
        )
    }
}
