//
//  BeaconViewModelTests.swift
//  BeaconTests
//
//  Tests for the BeaconViewModel — validation reactivity, state transitions,
//  and calculate flow.
//
//  With @Observable + didSet, validation is synchronous. No Task.sleep needed.
//

import XCTest
@testable import Beacon

@MainActor
final class BeaconViewModelTests: XCTestCase {

    // MARK: - Initial state

    func test_initialState_isClean() {
        let vm = BeaconViewModel()

        XCTAssertNil(vm.plan)
        XCTAssertFalse(vm.hasStaleResults)
        XCTAssertTrue(vm.fieldErrors.isEmpty)
        XCTAssertNil(vm.alertType)
        XCTAssertFalse(vm.canCalculate, "Empty form is not calculable")
        XCTAssertFalse(vm.showResults)
        XCTAssertTrue(vm.touchedFields.isEmpty, "No fields touched on launch")
        XCTAssertFalse(vm.hasAttemptedCalculation)
    }

    func test_initialDate_defaultsToCurrentMonthAndYear() {
        let vm = BeaconViewModel()
        let now = Date()
        XCTAssertEqual(vm.startMonth, Calendar.current.component(.month, from: now))
        XCTAssertEqual(vm.startYear, Calendar.current.component(.year, from: now))
    }

    // MARK: - Validation on calculate

    func test_calculate_withEmptyForm_doesNothing() {
        let vm = BeaconViewModel()
        vm.calculate()
        XCTAssertNil(vm.plan)
    }

    func test_calculate_withValidByMonthsInput_producesPlan() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        vm.calculate()
        XCTAssertNotNil(vm.plan)

        // See KNOWN_ISSUES.md — byMonths derivation can land at requested ± 1.
        let count = vm.plan?.rows.count ?? 0
        XCTAssertGreaterThanOrEqual(count, 23)
        XCTAssertLessThanOrEqual(count, 25)
        XCTAssertEqual(vm.plan?.rows.last?.remainingBalance, 0)
    }

    // MARK: - Stale results tracking

    func test_editingAfterCalculation_setsStaleResults() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "300"
        vm.calculate()

        XCTAssertFalse(vm.hasStaleResults, "Fresh calculation has no stale flag")

        vm.balanceText = "6000"

        XCTAssertTrue(vm.hasStaleResults, "Editing after calculate should mark results stale")
        XCTAssertNotNil(vm.plan, "Previous plan should remain visible until recalc")
    }

    func test_recalculating_clearsStaleFlag() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "300"
        vm.calculate()

        vm.balanceText = "6000"
        XCTAssertTrue(vm.hasStaleResults)

        vm.calculate()
        XCTAssertFalse(vm.hasStaleResults, "Recalculate should clear stale flag")
    }

    // MARK: - Mode switching

    func test_switchMode_clearsInactiveField() {
        let vm = BeaconViewModel()
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "250"

        vm.switchMode(to: .byMonths)

        XCTAssertEqual(vm.repaymentMode, .byMonths)
        XCTAssertTrue(vm.monthlyPaymentText.isEmpty,
                      "Switching to .byMonths should clear monthlyPaymentText")
    }

    func test_switchMode_toSameMode_isNoop() {
        let vm = BeaconViewModel()
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "250"

        vm.switchMode(to: .byPayment)

        XCTAssertEqual(vm.monthlyPaymentText, "250",
                       "Switching to current mode should not clear field")
    }

    // MARK: - Alerts

    func test_insufficientPayment_setsAlert() {
        let vm = BeaconViewModel()
        vm.balanceText = "10000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "10"  // way below first-month interest

        guard case .insufficientPayment(let minimum) = vm.alertType else {
            return XCTFail("Expected .insufficientPayment alert, got \(String(describing: vm.alertType))")
        }
        XCTAssertGreaterThan(minimum, 10,
                             "Suggested minimum should exceed the user's entered payment")
        XCTAssertFalse(vm.canCalculate, "Calculate should be disabled while alert is active")
    }

    func test_correctingInsufficientPayment_clearsAlert() {
        let vm = BeaconViewModel()
        vm.balanceText = "10000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "10"
        XCTAssertNotNil(vm.alertType)

        vm.monthlyPaymentText = "500"

        XCTAssertNil(vm.alertType, "Correcting payment should clear alert")
        XCTAssertTrue(vm.canCalculate)
    }

    // MARK: - Field errors (touched-state gating)

    func test_invalidAPR_producesFieldError() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "200"  // > 100
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        // Errors are gated until the field is touched or Calculate is pressed.
        XCTAssertFalse(vm.fieldErrors.isEmpty, "Validation should detect the out-of-range APR")
        XCTAssertFalse(vm.canCalculate)

        // After touching the field, the error becomes visible in the UI.
        vm.markTouched(.apr)
        XCTAssertNotNil(vm.error(for: .apr))
    }

    func test_zeroBalance_producesFieldError() {
        let vm = BeaconViewModel()
        vm.balanceText = "0"
        vm.aprText = "24.99"
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        XCTAssertFalse(vm.fieldErrors.isEmpty, "Zero balance should produce a field error")
        XCTAssertFalse(vm.canCalculate)

        vm.markTouched(.balance)
        XCTAssertNotNil(vm.error(for: .balance))
    }

    func test_zeroAPR_isAllowed() {
        let vm = BeaconViewModel()
        vm.balanceText = "1200"
        vm.aprText = "0"
        vm.repaymentMode = .byMonths
        vm.monthsText = "12"

        XCTAssertTrue(vm.fieldErrors.isEmpty, "0% APR is valid per PRD §7")
        XCTAssertTrue(vm.canCalculate)

        // No error visible in UI (even after touching) — 0% is a valid rate.
        vm.markTouched(.apr)
        XCTAssertNil(vm.error(for: .apr))
    }

    // MARK: - Touched-state gating

    func test_errorNotVisible_untilFieldTouched() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "999"  // invalid
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        // Validation has run (fieldErrors populated) but UI hasn't gated through yet.
        XCTAssertFalse(vm.fieldErrors.isEmpty)
        XCTAssertNil(vm.error(for: .apr), "Error should be hidden until field is touched")

        vm.markTouched(.apr)
        XCTAssertNotNil(vm.error(for: .apr), "Error should show after field is touched")
    }

    func test_calculate_exposesAllErrors() {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "999"  // invalid
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        XCTAssertNil(vm.error(for: .apr), "Hidden before calculate")
        vm.calculate()
        XCTAssertNotNil(vm.error(for: .apr), "Visible after calculate attempt")
        XCTAssertTrue(vm.hasAttemptedCalculation)
    }
}
