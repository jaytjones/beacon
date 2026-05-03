//
//  RepaymentMode.swift
//  Beacon
//
//  Enum for the two repayment input modes.
//

import Foundation

enum RepaymentMode: String, CaseIterable, Equatable {
    case byMonths      = "By months"
    case byPayment     = "By payment amount"
}
