//
//  SPO2SectionView.swift
//  Halo
//
//  SPO2 feature: realtime blood oxygen streaming.
//

import SwiftUI

struct SPO2SectionView: View {
    @Bindable var ringSessionManager: RingSessionManager

    var body: some View {
        Section(L10n.SPO2.sectionTitle) {
            Button {
                ringSessionManager.startRealTimeStreaming(type: .spo2)
            } label: {
                Text(L10n.SPO2.streamingStart)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.spo2Start)

            Button {
                ringSessionManager.continueRealTimeStreaming(type: .spo2)
            } label: {
                Text(L10n.SPO2.streamingContinue)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.spo2Continue)

            Button {
                ringSessionManager.stopRealTimeStreaming(type: .spo2)
            } label: {
                Text(L10n.SPO2.streamingStop)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.spo2Stop)
        }
    }
}
