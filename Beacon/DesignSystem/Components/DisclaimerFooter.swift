//
//  DisclaimerFooter.swift
//  Beacon
//
//  Static legal disclaimer footer.
//
//  Native audit: trivially native — a single `Text` with tokenized styling.
//  Copy is held as a static constant since it's a regulatory string that
//  shouldn't be passed in or accidentally varied at the call site.
//

import SwiftUI

struct DisclaimerFooter: View {

    static let text = "Beacon provides estimates only and does not constitute financial advice."

    var body: some View {
        Text(Self.text)
            .font(.beaconCaption)
            .foregroundStyle(Color.beaconTextSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Self.text)
    }
}

#Preview {
    DisclaimerFooter()
        .padding(BeaconSpacing.lg)
}
