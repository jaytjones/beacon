//
//  BeaconUITests.swift
//  BeaconUITests
//
//  End-to-end UI tests covering the three main user flows: happy-path
//  calculation, insufficient-payment recovery, and recalculation with
//  stale-results notice.
//

import XCTest

final class BeaconUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Flow 1: Happy path (by months)

    /// Enter a valid balance, APR, and term → tap Calculate → verify results appear.
    @MainActor
    func testHappyPath_byMonthsCalculation() throws {
        // The app launches with "By months" selected by default.
        let balanceField = app.textFields["Balance"]
        XCTAssertTrue(balanceField.waitForExistence(timeout: 3))
        balanceField.tap()
        balanceField.typeText("5000")

        let aprField = app.textFields["APR"]
        aprField.tap()
        aprField.typeText("24.99")

        let monthsField = app.textFields["Months"]
        monthsField.tap()
        monthsField.typeText("24")

        dismissKeyboard()

        let calculateButton = app.buttons["Calculate"]
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 2))
        XCTAssertTrue(calculateButton.isEnabled, "Calculate should be enabled with valid inputs")
        calculateButton.tap()

        // Results pane contains the "Payoff Date" stat card label.
        XCTAssertTrue(
            app.staticTexts["Payoff Date"].waitForExistence(timeout: 3),
            "Results should show the Payoff Date stat after a successful calculation"
        )
        XCTAssertTrue(app.staticTexts["Total Interest"].exists)
    }

    // MARK: - Flow 2: Insufficient payment → recovery → calculate

    /// Enter a payment too low to cover first-month interest → see the inline
    /// alert → correct the payment → verify alert disappears → calculate → verify results.
    @MainActor
    func testInsufficientPaymentRecovery() throws {
        // Switch to "By payment amount" mode.
        let modeControl = app.segmentedControls["Repayment mode"]
        XCTAssertTrue(modeControl.waitForExistence(timeout: 3))
        modeControl.buttons["By payment amount"].tap()

        let balanceField = app.textFields["Balance"]
        balanceField.tap()
        balanceField.typeText("10000")

        let aprField = app.textFields["APR"]
        aprField.tap()
        aprField.typeText("24.99")

        let paymentField = app.textFields["Monthly payment"]
        paymentField.tap()
        paymentField.typeText("10")  // well below first-month interest (~$212)

        dismissKeyboard()

        // Inline alert should appear reactively (no Calculate tap needed).
        let alertPredicate = NSPredicate(format: "label BEGINSWITH 'Alert: Your payment'")
        XCTAssertTrue(
            app.staticTexts.element(matching: alertPredicate).waitForExistence(timeout: 3),
            "Insufficient-payment alert should appear when payment is below first-month interest"
        )
        XCTAssertFalse(
            app.buttons["Calculate"].isEnabled,
            "Calculate must be disabled while an alert is active"
        )

        // Correct the payment to a sufficient amount.
        paymentField.tap()
        clearAndType("400", into: paymentField)

        dismissKeyboard()

        // Alert should clear reactively once payment covers interest.
        XCTAssertFalse(
            app.staticTexts.element(matching: alertPredicate).waitForExistence(timeout: 3),
            "Alert should disappear after correcting the payment"
        )
        XCTAssertTrue(app.buttons["Calculate"].isEnabled, "Calculate should be enabled now")

        app.buttons["Calculate"].tap()

        XCTAssertTrue(
            app.staticTexts["Payoff Date"].waitForExistence(timeout: 3),
            "Results should appear after a successful recalculation"
        )
    }

    // MARK: - Flow 3: Recalculation with stale-results notice

    /// Produce a plan → edit an input → verify the stale notice appears →
    /// tap Calculate again → verify the notice disappears and results update.
    @MainActor
    func testRecalculation_showsAndClearsStaleNotice() throws {
        // Produce an initial plan in By payment amount mode.
        let modeControl = app.segmentedControls["Repayment mode"]
        XCTAssertTrue(modeControl.waitForExistence(timeout: 3))
        modeControl.buttons["By payment amount"].tap()

        let balanceField = app.textFields["Balance"]
        balanceField.tap()
        balanceField.typeText("5000")

        let aprField = app.textFields["APR"]
        aprField.tap()
        aprField.typeText("18")

        let paymentField = app.textFields["Monthly payment"]
        paymentField.tap()
        paymentField.typeText("200")

        dismissKeyboard()

        app.buttons["Calculate"].tap()

        XCTAssertTrue(
            app.staticTexts["Payoff Date"].waitForExistence(timeout: 3),
            "Initial plan should appear"
        )

        // Edit the balance field to mark inputs as stale.
        balanceField.tap()
        clearAndType("6000", into: balanceField)
        dismissKeyboard()

        // Stale notice should fade in.
        let stalePredicate = NSPredicate(format: "label CONTAINS[c] 'inputs have changed'")
        XCTAssertTrue(
            app.staticTexts.element(matching: stalePredicate).waitForExistence(timeout: 3),
            "Stale-results notice should appear after editing an input post-calculation"
        )

        // Recalculate.
        app.buttons["Calculate"].tap()

        // Stale notice should disappear.
        let staleElement = app.staticTexts.element(matching: stalePredicate)
        let staleGone = staleElement.waitForExistence(timeout: 2)
        XCTAssertFalse(staleGone, "Stale notice should disappear after recalculation")

        // Fresh results should still be visible.
        XCTAssertTrue(app.staticTexts["Payoff Date"].exists, "Results should remain after recalculation")
    }

    // MARK: - Helpers

    /// Tap the "Done" button in the keyboard toolbar to dismiss the keyboard.
    private func dismissKeyboard() {
        let doneButton = app.toolbars.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
        }
    }

    /// Select all text in a field and type the replacement value.
    private func clearAndType(_ text: String, into element: XCUIElement) {
        element.tap()
        // Triple-tap selects all text in a text field on iOS.
        element.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        element.typeText(XCUIKeyboardKey.delete.rawValue)
        element.typeText(text)
    }
}
