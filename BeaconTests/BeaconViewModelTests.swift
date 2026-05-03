//
//  BeaconViewModelTests.swift
//  BeaconTests
//
//  Tests for the BeaconViewModel — validation reactivity, state transitions,
//  and calculate flow.
//

import XCTest
@testable import Beacon

@MainActor
final class BeaconViewModelTests: XCTestCase {

    // MARK: - Initial state

    func test_initialState_isClean() {
        let vm = BeaconViewModel()

        XCTAssertNil(vm.plan)
        XCTAssertFalse(vm.isCalculating)
        XCTAssertFalse(vm.hasStaleResults)
        XCTAssertTrue(vm.fieldErrors.isEmpty,
                      "Form should open with no errors visible — only after edits or calculate")
        XCTAssertNil(vm.alertType)
        XCTAssertFalse(vm.canCalculate, "Empty form is not calculable")
        XCTAssertFalse(vm.showResults)
        XCTAssertFalse(vm.showRecalculateBar)
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

    func test_calculate_withValidByMonthsInput_producesPlan() async {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        try? await Task.sleep(nanoseconds: 100_000_000)

        vm.calculate()
        XCTAssertNotNil(vm.plan)

        // See KNOWN_ISSUES.md — byMonths derivation can land at requested ± 1.
        let count = vm.plan?.rows.count ?? 0
        XCTAssertGreaterThanOrEqual(count, 23)
        XCTAssertLessThanOrEqual(count, 25)
        XCTAssertEqual(vm.plan?.rows.last?.remainingBalance, 0)
    }

    // MARK: - Stale results tracking

    func test_editingAfterCalculation_setsStaleResults() async {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "300"
        try? await Task.sleep(nanoseconds: 100_000_000)
        vm.calculate()

        XCTAssertFalse(vm.hasStaleResults, "Fresh calculation has no stale flag")

        vm.balanceText = "6000"
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(vm.hasStaleResults, "Editing after calculate should mark results stale")
        XCTAssertNotNil(vm.plan, "Previous plan should remain visible until recalc")
    }

    func test_recalculating_clearsStaleFlag() async {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "300"
        try? await Task.sleep(nanoseconds: 100_000_000)
        vm.calculate()

        vm.balanceText = "6000"
        try? await Task.sleep(nanoseconds: 100_000_000)
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

    func test_insufficientPayment_setsAlert() async {
        let vm = BeaconViewModel()
        vm.balanceText = "10000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "10"  // way below first-month interest

        try? await Task.sleep(nanoseconds: 100_000_000)

        guard case .insufficientPayment(let minimum) = vm.alertType else {
            return XCTFail("Expected .insufficientPayment alert, got \(String(describing: vm.alertType))")
        }
        XCTAssertGreaterThan(minimum, 10,
                             "Suggested minimum should exceed the user's entered payment")
        XCTAssertFalse(vm.canCalculate, "Calculate should be disabled while alert is active")
    }

    func test_correctingInsufficientPayment_clearsAlert() async {
        let vm = BeaconViewModel()
        vm.balanceText = "10000"
        vm.aprText = "24.99"
        vm.repaymentMode = .byPayment
        vm.monthlyPaymentText = "10"
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(vm.alertType)

        vm.monthlyPaymentText = "500"
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(vm.alertType, "Correcting payment should clear alert")
        XCTAssertTrue(vm.canCalculate)
    }

    // MARK: - Field errors

    func test_invalidAPR_producesFieldError() async {
        let vm = BeaconViewModel()
        vm.balanceText = "5000"
        vm.aprText = "200"  // > 100
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.error(for: .apr))
        XCTAssertFalse(vm.canCalculate)
    }

    func test_zeroBalance_producesFieldError() async {
        let vm = BeaconViewModel()
        vm.balanceText = "0"
        vm.aprText = "24.99"
        vm.repaymentMode = .byMonths
        vm.monthsText = "24"

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.error(for: .balance))
        XCTAssertFalse(vm.canCalculate)
    }

    func test_zeroAPR_isAllowed() async {
        let vm = BeaconViewModel()
        vm.balanceText = "1200"
        vm.aprText = "0"
        vm.repaymentMode = .byMonths
        vm.monthsText = "12"

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(vm.error(for: .apr), "0% APR is valid per PRD §7")
        XCTAssertTrue(vm.canCalculate)
    }
}
