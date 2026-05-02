//
//  BeaconRootView.swift
//  Beacon
//
//  Root container. Owns the BeaconViewModel as @StateObject and passes it down.
//

import SwiftUI

struct BeaconRootView: View {
    var body: some View {
        Text("Beacon")
            .font(.beaconPageTitle)
            .foregroundStyle(Color.beaconTextPrimary)
    }
}

#Preview {
    BeaconRootView()
}

