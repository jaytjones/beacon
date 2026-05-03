//
//  InlineAlertView.swift
//  Beacon
//
//  Renders the active AlertType as an InlineNotice (.attention variant).
//  Owns the PRD-specified copy for each alert case so the message strings
//  live in exactly one place in the codebase.
//
//  Currency formatting uses Decimal.formatted(.currency(code:)) — built-in
//  iOS 15+. USD is hardcoded for v1 (US-only per PRD scope); v1.1 multi-
//  currency would inject the code from a higher-level config.
//

import SwiftUI

struct InlineAlertView: View {
    let alertType: AlertType

    var body: some View {
        InlineNotice(variant: .attention, message: message)
    }

    private var message: String {
        switch alertType {
        case .insufficientPayment(let minimum):
            let formatted = minimum.formatted(.currency(code: "USD"))
            return "Your payment doesn't cover the monthly interest. Try increasing it to at least \(formatted)."
        case .termExceedsMax:
            return "At this payment amount, your balance won't be paid off within 30 years. Try increasing your monthly payment."
        }
    }
}
