//
//  DeviceSectionView.swift
//  Halo
//
//  Device feature: ring connection, add/remove, connect.
//

import SwiftUI

struct DeviceSectionView: View {
    @Bindable var ringSessionManager: RingSessionManager
    @Binding var showAddRingSheet: Bool

    var body: some View {
        Section(L10n.Device.sectionTitle) {
            if ringSessionManager.savedRingIdentifier != nil {
                VStack(alignment: .leading, spacing: 8) {
                    makeRingView(displayName: ringSessionManager.ringDisplayName ?? L10n.Device.defaultRingName)
                    if !ringSessionManager.peripheralConnected {
                        if ringSessionManager.isScanningForRing {
                            Text(L10n.Device.searching)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(L10n.Device.searching)
                        } else {
                            Button {
                                ringSessionManager.findRingAgain()
                            } label: {
                                Text(L10n.Device.connect)
                                    .font(.subheadline.weight(.medium))
                            }
                            .accessibilityLabel(L10n.A11y.deviceConnect)
                            .accessibilityHint(Text(L10n.A11y.deviceReconnectHint))
                        }
                    }
                    Button(role: .destructive) {
                        ringSessionManager.removeRing()
                    } label: {
                        Text(L10n.Device.removeRing)
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityLabel(L10n.A11y.deviceRemoveRing)
                }
            } else {
                Button {
                    showAddRingSheet = true
                    ringSessionManager.startDiscovery()
                } label: {
                    Text(L10n.Device.addRing)
                        .frame(maxWidth: .infinity)
                        .font(Font.headline.weight(.semibold))
                }
                .accessibilityLabel(L10n.A11y.deviceAddRing)
            }
        }
    }

    private func makeRingView(displayName: String) -> some View {
        HStack {
            Image("colmi")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 70)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(displayName)
                    .font(Font.headline.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
        }
    }
}
