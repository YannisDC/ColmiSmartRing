//
//  BatterySectionView.swift
//  Halo
//
//  Battery feature: get status and display level/charging.
//

import SwiftUI

struct BatterySectionView: View {
    @Bindable var ringSessionManager: RingSessionManager

    var body: some View {
        Section(L10n.Battery.sectionTitle) {
            if let info = ringSessionManager.currentBatteryInfo {
                Text(L10n.Battery.level(info.batteryLevel))
                    .font(.title3.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Text(L10n.Battery.charging(info.charging ? L10n.Battery.chargingYes : L10n.Battery.chargingNo))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            } else {
                Text("--%")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
        }
    }
}
