//
//  AddRingSheetView.swift
//  Halo
//
//  Device feature: add ring sheet (discovery and connect).
//

import SwiftUI

struct AddRingSheetView: View {
    @Bindable var ringSessionManager: RingSessionManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Group {
                if ringSessionManager.isDiscovering && ringSessionManager.discoveredPeripherals.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .accessibilityLabel(Text(L10n.A11y.deviceSearching))
                        Text(L10n.Device.searchingForRing)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(ringSessionManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button {
                                ringSessionManager.connectAndSaveRing(peripheral: peripheral)
                            } label: {
                                Label(peripheral.name ?? peripheral.identifier.uuidString, systemImage: "antenna.radiowaves.left.and.right")
                            }
                            .accessibilityLabel(Text(peripheral.name ?? peripheral.identifier.uuidString))
                            .accessibilityHint(Text(L10n.A11y.deviceConnectHint))
                        }
                    }
                }
            }
            .navigationTitle(L10n.Device.addRingSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Device.cancel) {
                        ringSessionManager.stopDiscovery()
                        isPresented = false
                    }
                    .accessibilityLabel(L10n.Device.cancel)
                }
            }
        }
    }
}
