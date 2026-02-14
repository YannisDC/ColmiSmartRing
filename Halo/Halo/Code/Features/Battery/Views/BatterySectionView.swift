//
//  BatterySectionView.swift
//  Halo
//
//  Battery feature: get status and display level/charging.
//

import SwiftUI

struct BatterySectionView: View {
    @Bindable var ringSessionManager: RingSessionManager
    @State var batteryInfo: BatteryInfo?

    var body: some View {
        Section(L10n.Battery.sectionTitle) {
            Button {
                ringSessionManager.getBatteryStatus { info in
                    batteryInfo = info
                }
            } label: {
                Text(L10n.Battery.getStatus)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!ringSessionManager.peripheralConnected)
            .accessibilityLabel(L10n.A11y.batteryGet)
            .accessibilityHint(Text(L10n.A11y.batteryGetHint))

            if let info = batteryInfo {
                Text(L10n.Battery.level(info.batteryLevel))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Text(L10n.Battery.charging(info.charging ? L10n.Battery.chargingYes : L10n.Battery.chargingNo))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
        }
    }
}
