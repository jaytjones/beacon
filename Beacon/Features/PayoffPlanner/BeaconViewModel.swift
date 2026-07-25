//
//  BeaconViewModel.swift
//  Beacon
//
//  Single @Observable for the entire app. Owns form inputs, validation,
//  and the active PayoffPlan. No Combine — validation is synchronous via
//  didSet property observers, eliminating the 50ms debounce race.
//

import Foundation
import Observation

/// The single source of truth for Beacon's UI state.
///
/// Owned by `BeaconRootView` as `@State`; passed down to subviews as a plain
/// value (no wrapper for read-only consumers, `@Bindable` for consumers that
/// need `$viewModel.property` bindings). There is no other observable state
/// in the app — the only component-local state is `PayoffChartView`'s
/// `selectedRow` (tooltip visibility).
///
/// State categories:
///   - **Form inputs**: raw `String` properties bound to `TextField`s.
///   - **Computation state**: `plan`, `hasStaleResults`.
///   - **Validation**: `fieldErrors` and `alertType`, recomputed on every
///     input change via `didSet` → `handleInputChange()`.
///   - **Touch tracking**: `touchedFields` and `hasAttemptedCalculation`
///     gate visual error rendering so errors only appear on visited fields.
@Observable
@MainActor
final class BeaconViewModel {

    // MARK: - Form inputs

    var balanceText: String = "" { didSet { handleInputChange() } }
    var aprText: String = "" { didSet { handleInputChange() } }
    /// Changed only through `switchMode(to:)` — no didSet, mode clears
    /// the inactive field which then triggers its own handleInputChange.
    var repaymentMode: RepaymentMode = .byMonths
    var monthsText: String = "" { didSet { handleInputChange() } }
    var monthlyPaymentText: String = "" { didSet { handleInputChange() } }
    var startMonth: Int = Calendar.current.component(.month, from: Date()) { didSet { handleInputChange() } }
    var startYear: Int = Calendar.current.component(.year, from: Date()) { didSet { handleInputChange() } }

    // MARK: - Computation state

    private(set) var plan: PayoffPlan? = nil
    private(set) var hasStaleResults: Bool = false

    // MARK: - Validation

    private(set) var fieldErrors: [FieldError] = []
    private(set) var alertType: AlertType? = nil

    // MARK: - Touch tracking

    private(set) var touchedFields: Set<InputField> = []
    private(set) var hasAttemptedCalculation: Bool = false

    // MARK: - Derived

    var canCalculate: Bool {
        fieldErrors.isEmpty && alertType == nil && hasRequiredFields
    }

    var showResults: Bool { plan != nil }

    private var hasRequiredFields: Bool {
        let baseFilled = !balanceText.trimmingCharacters(in: .whitespaces).isEmpty
                      && !aprText.trimmingCharacters(in: .whitespaces).isEmpty
        switch repaymentMode {
        case .byMonths:
            return baseFilled && !monthsText.trimmingCharacters(in: .whitespaces).isEmpty
        case .byPayment:
            return baseFilled && !monthlyPaymentText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Lookup helpers for views

    func error(for field: InputField) -> String? {
        guard hasAttemptedCalculation || touchedFields.contains(field) else { return nil }
        return fieldErrors.first(where: { $0.field == field })?.message
    }

    // MARK: - Public actions

    func markTouched(_ field: InputField) {
        touchedFields.insert(field)
    }

    func revalidate() {
        let result = InputValidator.validate(currentRawInputs())
        fieldErrors = result.fieldErrors
        alertType = result.alertType
    }

    /// Run the calculator and update `plan`. Single validation pass — no
    /// second call to buildInput needed because validate() returns the
    /// pre-built RepaymentInput when valid.
    func calculate() {
        hasAttemptedCalculation = true
        let result = InputValidator.validate(currentRawInputs())
        fieldErrors = result.fieldErrors
        alertType = result.alertType
        guard let input = result.validatedInput else { return }

        let computed = AmortizationCalculator.calculate(input: input)
        guard !computed.rows.isEmpty else { return }

        self.plan = computed
        hasStaleResults = false
    }

    /// Switch repayment mode mid-entry. The inactive field's value and touch
    /// state are cleared so stale errors don't persist across mode switches.
    func switchMode(to newMode: RepaymentMode) {
        guard newMode != repaymentMode else { return }
        switch newMode {
        case .byMonths:
            monthlyPaymentText = ""
            touchedFields.remove(.monthlyPayment)
        case .byPayment:
            monthsText = ""
            touchedFields.remove(.months)
        }
        repaymentMode = newMode
        revalidate()
    }

    // MARK: - Private

    private func handleInputChange() {
        revalidate()
        if plan != nil { hasStaleResults = true }
    }

    private func currentRawInputs() -> InputValidator.RawInputs {
        InputValidator.RawInputs(
            balance: balanceText,
            apr: aprText,
            mode: repaymentMode,
            months: monthsText,
            monthlyPayment: monthlyPaymentText,
            startMonth: startMonth,
            startYear: startYear
        )
    }
}
