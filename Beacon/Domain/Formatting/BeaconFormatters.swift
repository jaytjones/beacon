//
//  BeaconFormatters.swift
//  Beacon
//
//  Unified formatting functions for currency and dates. All view code routes
//  through here — never allocate NumberFormatter or DateFormatter inline.
//
//  Uses modern .formatted APIs throughout so:
//    - Decimal values never round-trip through Double
//    - Output is locale-aware
//    - No formatter allocation per render call
//

import Foundation

enum BeaconFormatters {

    /// Format a Decimal as USD currency (e.g., "$1,234.56").
    static func currency(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    /// Format a Double as USD currency with no fraction digits (e.g., "$1,234").
    /// Use only for chart axis labels where Swift Charts provides Double values.
    static func currencyWhole(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// Format a Date as abbreviated month + year (e.g., "Jan 2026").
    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    /// Format a Date as full month + year (e.g., "January 2026").
    static func monthYearLong(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}
