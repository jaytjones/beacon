//
//  SummaryStatCard.swift
//  Beacon
//
//  Single stat tile used in SummaryRow. Three appear side-by-side.
//  The optional hero treatment renders the payoff date at beaconHeroNumber
//  scale using @ScaledMetric so it adapts to Dynamic Type.
//

import SwiftUI

struct SummaryStatCard: View {

    let label: String
    let value: String
    let isMono: Bool
    let isHero: Bool

    @ScaledMetric(relativeTo: .body) private var heroSize: CGFloat = 28

    init(
        label: String,
        value: String,
        isMono: Bool = false,
        isHero: Bool = false
    ) {
        self.label = label
        self.value = value
        self.isMono = isMono
        self.isHero = isHero
    }

    var body: some View {
        VStack(alignment: .center, spacing: BeaconSpacing.xs) {

            Text(label)
                .font(.beaconFieldLabel)
                .foregroundStyle(Color.beaconTextSecondary)
                .lineLimit(1)

            Text(value)
                .font(isHero
                    ? .system(size: heroSize, weight: .semibold, design: .rounded).monospacedDigit()
                    : (isMono ? .beaconBodyMono : .beaconBody))
                .foregroundStyle(isHero ? Color.beaconAccent : Color.beaconTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BeaconSpacing.md)
        .padding(.horizontal, BeaconSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: BeaconRadius.md)
                .fill(Color.beaconSurfaceAlt)
        )
    }
}
