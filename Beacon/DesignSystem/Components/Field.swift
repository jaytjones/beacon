//
//  Field.swift
//  Beacon
//
//  Standard text input. Wraps SwiftUI TextField with custom border, label,
//  inline error rendering, and focus styling.
//
//  Native audit: thin wrapper around `TextField`. Keeps the system input for
//  IME, copy/paste, accessibility, and Dynamic Type. The wrapper layers on:
//    - Label above the field (.beaconFieldLabel)
//    - 0.5px hairline border (1.5px sage on focus, 1.5px amber on error)
//    - Inline error rendering (icon + text — color is never the sole signal)
//    - Tabular-digit font option for numeric inputs (per usage-guide rule #2)
//
//  Border-width exception: the 1.5px focus/error width is a usage-site literal,
//  documented in the Beacon Design System Usage Guide as an explicit narrow
//  special case (no token).
//

import SwiftUI
import UIKit

struct Field: View {

    // MARK: - Inputs

    let label: String
    let placeholder: String
    @Binding var text: String

    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isMonospacedDigit: Bool = false

    /// Inline error to render under the field. Pass nil for the default state.
    var error: FieldError? = nil

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: BeaconSpacing.xs) {

            Text(label)
                .font(.beaconFieldLabel)
                .foregroundStyle(Color.beaconTextSecondary)

            TextField(placeholder, text: $text)
                .font(isMonospacedDigit ? .beaconBodyMono : .beaconBody)
                .foregroundStyle(Color.beaconTextPrimary)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .frame(height: BeaconLayout.fieldHeight)
                .padding(.horizontal, BeaconSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                        .fill(Color.beaconSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BeaconRadius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )
                .accessibilityLabel(label)
                .accessibilityValue(text.isEmpty ? "Empty" : text)

            if let error {
                HStack(alignment: .firstTextBaseline, spacing: BeaconSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .accessibilityHidden(true)
                    Text(error.message)
                }
                .font(.beaconAlert)
                .foregroundStyle(Color.beaconAttentionText)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label) error: \(error.message)")
            }
        }
    }

    // MARK: - Derived state

    private var borderColor: Color {
        if error != nil { return .beaconAttention }
        if isFocused    { return .beaconAccent }
        return .beaconBorder
    }

    private var borderWidth: CGFloat {
        (error != nil || isFocused) ? 1.5 : 0.5
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: BeaconSpacing.xl) {
        Field(
            label: "Balance",
            placeholder: "$0.00",
            text: .constant(""),
            keyboardType: .decimalPad,
            isMonospacedDigit: true
        )

        Field(
            label: "APR",
            placeholder: "e.g. 24.99 for 24.99% APR",
            text: .constant("24.99"),
            keyboardType: .decimalPad,
            isMonospacedDigit: true
        )

        Field(
            label: "Balance",
            placeholder: "$0.00",
            text: .constant(""),
            keyboardType: .decimalPad,
            isMonospacedDigit: true,
            error: FieldError(field: .balance, message: "Please enter a balance greater than $0")
        )
    }
    .padding(BeaconSpacing.lg)
}
