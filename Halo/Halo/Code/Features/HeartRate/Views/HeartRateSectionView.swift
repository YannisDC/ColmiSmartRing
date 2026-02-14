//
//  HeartRateSectionView.swift
//  Halo
//
//  Heart rate feature: log, graph, realtime streaming.
//

import SwiftUI
import SwiftData

struct HeartRateSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ringSessionManager: RingSessionManager
    @Query(sort: \StoredHeartRateLog.timestamp, order: .reverse) private var storedHeartRateLogs: [StoredHeartRateLog]
    @State private var data: [HeartRateDataPoint] = []
    private static let swiftDataLogDateFormatter = ISO8601DateFormatter()

    var body: some View {
        Section(L10n.HeartRate.logSectionTitle) {
            Button {
                ringSessionManager.getHeartRateLog { hrl in
                    Task { @MainActor in
                        saveHeartRateLog(hrl)
                        do {
                            let heartRatesWithTimes = try hrl.heartRatesWithTimes()
                            data = heartRatesWithTimes.map { HeartRateDataPoint(heartRate: $0.0, time: $0.1) }
                        } catch {
                            print("Error loading data: \(error)")
                        }
                    }
                }
            } label: {
                Text(L10n.HeartRate.getLog)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!ringSessionManager.peripheralConnected)
            .accessibilityLabel(L10n.A11y.heartRateGetLog)
        }

        HeartRateGraphView(data: data)

        Section(L10n.HeartRate.sectionTitle) {
            Button {
                ringSessionManager.startRealTimeStreaming(type: .heartRate)
            } label: {
                Text(L10n.HeartRate.streamingStart)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.heartRateStart)

            Button {
                ringSessionManager.continueRealTimeStreaming(type: .heartRate)
            } label: {
                Text(L10n.HeartRate.streamingContinue)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.heartRateContinue)

            Button {
                ringSessionManager.stopRealTimeStreaming(type: .heartRate)
            } label: {
                Text(L10n.HeartRate.streamingStop)
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .accessibilityLabel(L10n.A11y.heartRateStop)
        }
        .onAppear {
            loadMostRecentHeartRateFromStorage()
        }
    }

    private func loadMostRecentHeartRateFromStorage() {
        guard let log = storedHeartRateLogs.first else { return }
        do {
            let heartRatesWithTimes = try log.toHeartRateLog().heartRatesWithTimes()
            data = heartRatesWithTimes.map { HeartRateDataPoint(heartRate: $0.0, time: $0.1) }
        } catch {
            print("Error loading stored heart rate: \(error)")
        }
    }

    private func saveHeartRateLog(_ log: HeartRateLog) {
        let dayStart = Calendar.current.startOfDay(for: log.timestamp)
        let descriptor = FetchDescriptor<StoredHeartRateLog>(
            predicate: #Predicate<StoredHeartRateLog> { $0.dayStart == dayStart }
        )
        let action: String
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.timestamp = log.timestamp
            existing.heartRates = log.heartRates
            existing.size = log.size
            existing.index = log.index
            existing.range = log.range
            action = "UPDATE"
        } else {
            let stored = StoredHeartRateLog.from(log)
            modelContext.insert(stored)
            action = "INSERT"
        }
        let nonZeroEntries = log.heartRates.enumerated()
            .filter { $0.element > 0 }
            .map { offset, bpm in
                let minutes = offset * log.range
                return "{minute: \(minutes), bpm: \(bpm)}"
            }
            .joined(separator: ", ")

        print("========= SWIFTDATA SAVE: Heart Rate Log =========")
        print("action: \(action)")
        print("dayStart: \(swiftDataLogDate(dayStart))")
        print("timestamp: \(swiftDataLogDate(log.timestamp))")
        print("size: \(log.size), index: \(log.index), range: \(log.range)")
        print("nonZeroHeartRates: [\(nonZeroEntries)]")
        do {
            try modelContext.save()
            print("result: SUCCESS")
        } catch {
            print("result: FAILED - \(error)")
        }
        print("==================================================")
    }

    private func swiftDataLogDate(_ date: Date) -> String {
        Self.swiftDataLogDateFormatter.string(from: date)
    }
}
