//
//  BeaconViewModel.swift
//  Beacon
//
//  Single ObservableObject for the entire app. Owns form inputs, validation,
//  and the active PayoffPlan.
//

import Foundation
import Combine

/// The single source of truth for Beacon's UI state.
///
/// Owned by `BeaconRootView` as `@StateObject`; passed down to subviews as
/// `@ObservedObject`. There is no other observable state in the app — the only
/// component-local state is `PayoffChartView`'s `selectedRow` (tooltip
/// visibility), which doesn't need to live here.
///
/// State categories:
///   - **Form inputs**: raw `String` properties bound to `TextField`s.
///   - **Computation state**: `plan`, `hasStaleResults`.
///   - **Validation**: `fieldErrors` and `alertType`, recomputed reactively.
///   - **Touch tracking**: `touchedFields` and `hasAttemptedCalculation`
///     gate visual error rendering so errors only appear on visited fields.
///
/// Validation strategy (tech spec §4.2):
///   - Format errors (non-numeric) refresh as the user edits.
///   - Business-logic errors (insufficientPayment, termExceedsMax) refresh
///     reactively, so the inline alert appears live in the payment field.
///   - The Calculate button's enabled state is derived from `canCalculate`.
@MainActor
final class BeaconViewModel: ObservableObject {

    // MARK: - Form inputs

    @Published var balanceText: String = ""
    @Published var aprText: String = ""
    @Published var repaymentMode: RepaymentMode = .byMonths
    @Published var monthsText: String = ""
    @Published var monthlyPaymentText: String = ""
    @Published var startMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var startYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - Computation state

    /// nil until the first successful calculation.
    @Published private(set) var plan: PayoffPlan? = nil

    /// True when inputs have been edited after a successful calculation.
    /// Drives `StaleResultsNotice` visibility (tech spec §3.2).
    @Published private(set) var hasStaleResults: Bool = false

    // MARK: - Validation

    @Published private(set) var fieldErrors: [FieldError] = []
    @Published private(set) var alertType: AlertType? = nil

    // MARK: - Touch tracking

    /// Fields the user has interacted with (lost focus at least once).
    /// Errors render only for touched fields or after Calculate is first pressed.
    @Published private(set) var touchedFields: Set<InputField> = []

    /// True once the user has tapped Calculate. After this, all field errors
    /// are visible regardless of individual touch state.
    private(set) var hasAttemptedCalculation: Bool = false

    // MARK: - Derived

    var canCalculate: Bool {
        fieldErrors.isEmpty && alertType == nil && hasRequiredFields
    }

    var showResults: Bool { plan != nil }

    /// Cheap presence check — does NOT validate format or range. Used as a
    /// guard before validation runs at all. Mirrors the logic of "the
    /// Calculate button stays disabled until all required fields are
    /// populated" (PRD Feature 1 acceptance criteria).
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

    /// Pull the inline error message for a specific field, if any.
    /// Returns nil until the field has been touched or Calculate has been pressed,
    /// so errors never appear on fields the user hasn't visited yet.
    func error(for field: InputField) -> String? {
        guard hasAttemptedCalculation || touchedFields.contains(field) else { return nil }
        return fieldErrors.first(where: { $0.field == field })?.message
    }

    // MARK: - Public actions

    /// Record that a field has lost focus. Called from each field's `onFocusLost`
    /// callback. Enables error display for that field going forward.
    func markTouched(_ field: InputField) {
        touchedFields.insert(field)
    }

    /// Run validation against current form state. Called reactively as the
    /// user edits, and also explicitly when the user taps Calculate.
    func revalidate() {
        let raw = currentRawInputs()
        let result = InputValidator.validate(raw)
        fieldErrors = result.fieldErrors
        alertType = result.alertType
    }

    /// Run the calculator and update `plan`. No-op if validation fails.
    func calculate() {
        hasAttemptedCalculation = true
        revalidate()
        guard canCalculate, let input = InputValidator.buildInput(from: currentRawInputs()) else {
            return
        }

        let result = AmortizationCalculator.calculate(input: input)
        // Validator catches all paths that produce an empty plan; treat this
        // as an invariant violation and bail without surfacing a confusing alert.
        guard !result.rows.isEmpty else { return }

        self.plan = result
        hasStaleResults = false
    }

    /// Switch repayment mode mid-entry. Per PRD Feature 1 + tech spec §6.1,
    /// the inactive field's value and touch state are cleared.
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

    // MARK: - Init / reactive wiring

    private var cancellables: Set<AnyCancellable> = []

    init() {
        setupBindings()
    }

    /// Wire the reactive validation pipeline. Any change to a form field or
    /// the start date triggers a revalidation; any change to a form field
    /// after a successful calculation also flips `hasStaleResults` true.
    private func setupBindings() {
        let formChanges = Publishers.MergeMany(
            $balanceText.map { _ in () }.eraseToAnyPublisher(),
            $aprText.map { _ in () }.eraseToAnyPublisher(),
            $monthsText.map { _ in () }.eraseToAnyPublisher(),
            $monthlyPaymentText.map { _ in () }.eraseToAnyPublisher(),
            $repaymentMode.map { _ in () }.eraseToAnyPublisher(),
            $startMonth.map { _ in () }.eraseToAnyPublisher(),
            $startYear.map { _ in () }.eraseToAnyPublisher()
        )

        formChanges
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.revalidate()
                if self?.plan != nil {
                    self?.hasStaleResults = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Internal

    /// Snapshot the current raw form state for validation.
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
