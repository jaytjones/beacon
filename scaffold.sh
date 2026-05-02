#!/bin/bash
set -e

cd Beacon  # the inner Beacon source folder, not the repo root

# --- Create folder structure ---
mkdir -p App
mkdir -p DesignSystem/Components
mkdir -p Features/PayoffPlanner/Chrome
mkdir -p Features/PayoffPlanner/InputForm
mkdir -p Features/PayoffPlanner/Results
mkdir -p Domain/Models
mkdir -p Domain/Calculation
mkdir -p Domain/Validation
mkdir -p Resources

# --- Helper: create a placeholder Swift file with a header ---
make_swift() {
  local path=$1
  local filename=$(basename "$path")
  local description=$2

  if [ ! -f "$path" ]; then
    cat > "$path" << EOF
//
//  $filename
//  Beacon
//
//  $description
//

import Foundation

EOF
  fi
}

make_swift_ui() {
  local path=$1
  local filename=$(basename "$path")
  local description=$2

  if [ ! -f "$path" ]; then
    cat > "$path" << EOF
//
//  $filename
//  Beacon
//
//  $description
//

import SwiftUI

EOF
  fi
}

# --- App ---
make_swift_ui "App/BeaconRootView.swift" "Root container. Owns the BeaconViewModel as @StateObject and passes it down."

# --- DesignSystem/Components ---
make_swift_ui "DesignSystem/Components/Field.swift" "Standard text input. Wraps SwiftUI TextField with custom border, label, and focus styling."
make_swift_ui "DesignSystem/Components/PrimaryButton.swift" "Primary action button. Native Button with custom fill, label, and loading state."
make_swift_ui "DesignSystem/Components/MenuField.swift" "Dropdown trigger. Wraps SwiftUI Menu; styles the closed trigger to match Field."
make_swift_ui "DesignSystem/Components/InlineNotice.swift" "Reusable inline notice surface. Powers InlineAlertView and StaleResultsNotice."
make_swift_ui "DesignSystem/Components/SummaryStatCard.swift" "Single stat tile used in SummaryRow. Hosts the beaconHeroNumber for the payoff date."
make_swift_ui "DesignSystem/Components/DisclaimerFooter.swift" "Static legal disclaimer text shown at the bottom of the screen."

# --- Features/PayoffPlanner ---
make_swift "Features/PayoffPlanner/BeaconViewModel.swift" "Single ObservableObject for the entire app. Owns form inputs, validation, and the active PayoffPlan."

# Chrome
make_swift_ui "Features/PayoffPlanner/Chrome/RecalculateBar.swift" "Sticky top bar shown after the first calculation. Tap scrolls to InputFormView."
make_swift_ui "Features/PayoffPlanner/Chrome/StaleResultsNotice.swift" "Inline notice shown below the form when inputs are edited post-calc."

# InputForm
make_swift_ui "Features/PayoffPlanner/InputForm/InputFormView.swift" "Container for all input fields, mode toggle, date picker, calculate button, and inline alerts."
make_swift_ui "Features/PayoffPlanner/InputForm/BalanceField.swift" "Currency input for the user's current credit card balance."
make_swift_ui "Features/PayoffPlanner/InputForm/APRField.swift" "Percentage input for the card's APR."
make_swift_ui "Features/PayoffPlanner/InputForm/RepaymentModeSelector.swift" "Pill toggle / segmented control for choosing By months vs By payment amount."
make_swift_ui "Features/PayoffPlanner/InputForm/MonthsField.swift" "Integer input for target repayment term in months. Shown only in .byMonths mode."
make_swift_ui "Features/PayoffPlanner/InputForm/MonthlyPaymentField.swift" "Currency input for desired monthly payment. Shown only in .byPayment mode."
make_swift_ui "Features/PayoffPlanner/InputForm/StartDatePicker.swift" "Two MenuField dropdowns: Month and Year. Defaults to current month/year."
make_swift_ui "Features/PayoffPlanner/InputForm/CalculateButton.swift" "Primary action. Disabled when canCalculate is false. Shows spinner while calculating."
make_swift_ui "Features/PayoffPlanner/InputForm/InlineAlertView.swift" "Inline alert for insufficientPayment and termExceedsMax conditions. Icon + text."

# Results
make_swift_ui "Features/PayoffPlanner/Results/ResultsView.swift" "Container shown after first successful calculation. Holds SummaryRow, chart, and table."
make_swift_ui "Features/PayoffPlanner/Results/SummaryRow.swift" "Three-stat row above the table: total interest, payoff date (hero), total months."
make_swift_ui "Features/PayoffPlanner/Results/PayoffChartView.swift" "SwiftUI Charts line graph of remaining balance over time."
make_swift_ui "Features/PayoffPlanner/Results/ChartTooltipOverlay.swift" "Tap-driven tooltip overlay for PayoffChartView. Uses .chartOverlay coordinate mapping."
make_swift_ui "Features/PayoffPlanner/Results/AmortizationTableView.swift" "Independent ScrollView containing a LazyVStack of AmortizationRowView."
make_swift_ui "Features/PayoffPlanner/Results/AmortizationRowView.swift" "Single row of the amortization table. Columns: month, date, payment, interest, principal, balance."

# --- Domain (NO SwiftUI imports) ---
make_swift "Domain/Models/RepaymentMode.swift" "Enum for the two repayment input modes."
make_swift "Domain/Models/RepaymentInput.swift" "Validated user input snapshot. Passed to AmortizationCalculator."
make_swift "Domain/Models/AmortizationRow.swift" "One month of the payoff plan."
make_swift "Domain/Models/PayoffPlan.swift" "Complete output of a calculation run."
make_swift "Domain/Models/AlertType.swift" "Enum distinguishing insufficientPayment and termExceedsMax alert conditions."
make_swift "Domain/Models/ValidationResult.swift" "Synchronous validation output: errors, alert type, isValid."
make_swift "Domain/Calculation/AmortizationCalculator.swift" "Pure Swift struct. Takes RepaymentInput, returns PayoffPlan. Decimal arithmetic throughout."
make_swift "Domain/Validation/InputValidator.swift" "Validates raw form input strings, produces ValidationResult."

echo "✅ Folder structure created."
echo ""
echo "Next: open Beacon.xcodeproj and drag the new folders into the Beacon group."
