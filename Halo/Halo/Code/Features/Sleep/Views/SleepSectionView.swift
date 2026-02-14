//
//  SleepSectionView.swift
//  Halo
//
//  Sleep feature: request sleep data, display sleep stages and stored nights.
//

import SwiftUI
import SwiftData

struct SleepSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ringSessionManager: RingSessionManager
    @Query(sort: \StoredSleepDay.syncDate, order: .reverse) private var storedSleepDays: [StoredSleepDay]
    @State private var lastSleepData: SleepData?
    @State private var lastBigDataSleep: BigDataSleepData?
    @State private var selectedStoredSleepDay: StoredSleepDay?

    private var sortedStoredSleepDays: [StoredSleepDay] {
        storedSleepDays.sorted { $0.sleepDate > $1.sleepDate }
    }

    var body: some View {
        Section(L10n.Sleep.sectionTitle) {
            Button {
                ringSessionManager.syncSleep(dayOffset: 0)
            } label: {
                Label(L10n.Sleep.requestData, systemImage: "bed.double.fill")
                    .frame(maxWidth: .infinity)
                    .font(Font.headline.weight(.semibold))
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!ringSessionManager.peripheralConnected)
            .accessibilityLabel(L10n.A11y.sleepRequest)
            .accessibilityHint(Text(L10n.A11y.sleepRequestHint))

            if let sleep = lastBigDataSleep, let firstDay = sleep.days.first {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.Sleep.daysCount(sleep.days.count))
                        .font(.subheadline.weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    SleepStageGraphView(day: firstDay)
                    SleepChartKitView(day: firstDay)
                    if sleep.days.count > 1 {
                        DisclosureGroup(L10n.Sleep.otherNights) {
                            ForEach(Array(sleep.days.dropFirst().enumerated()), id: \.offset) { _, day in
                                SleepStageGraphView(day: day)
                                SleepChartKitView(day: day)
                            }
                        }
                    }
                }
            } else if let sleep = lastSleepData {
                VStack(alignment: .leading, spacing: 4) {
                    if let date = sleep.date {
                        Text(date, style: .date)
                            .font(.subheadline.weight(.medium))
                    }
                    Text(L10n.Sleep.timeQualities(time: sleep.time, qualities: sleep.sleepQualities))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !sortedStoredSleepDays.isEmpty {
                DisclosureGroup(L10n.Sleep.storedNights(sortedStoredSleepDays.count)) {
                    ForEach(sortedStoredSleepDays) { storedDay in
                        Button {
                            selectedStoredSleepDay = selectedStoredSleepDay?.id == storedDay.id ? nil : storedDay
                        } label: {
                            HStack {
                                Text(storedDay.sleepDate, style: .date)
                                Text(L10n.Sleep.daysAgo(Int(storedDay.daysAgo)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(storedDay.sleepDate, style: .date))
                        .accessibilityHint(Text(L10n.A11y.sleepStoredDayHint))
                        if selectedStoredSleepDay?.id == storedDay.id {
                            let day = storedDay.toSleepDay()
                            VStack(alignment: .leading, spacing: 8) {
                                SleepStageGraphView(day: day)
                                SleepChartKitView(day: day, nightDate: storedDay.sleepDate)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            ringSessionManager.sleepDataCallback = { lastSleepData = $0 }
            ringSessionManager.bigDataSleepCallback = { bigData in
                Task { @MainActor in
                    lastBigDataSleep = bigData
                    saveBigDataSleep(bigData)
                }
            }
        }
    }

    private func saveBigDataSleep(_ bigData: BigDataSleepData) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for day in bigData.days {
            let daysAgo = Int(day.daysAgo)
            let nightDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let descriptor = FetchDescriptor<StoredSleepDay>(
                predicate: #Predicate<StoredSleepDay> { $0.daysAgo == daysAgo }
            )
            let existing = (try? modelContext.fetch(descriptor))?.first
            if let existingDay = existing {
                existingDay.sleepStart = Int(day.sleepStart)
                existingDay.sleepEnd = Int(day.sleepEnd)
                existingDay.syncDate = Date()
                for p in existingDay.periods { modelContext.delete(p) }
                existingDay.periods = []
                let newPeriods = makeStoredPeriods(from: day, nightDate: nightDate)
                for p in newPeriods {
                    p.day = existingDay
                    modelContext.insert(p)
                    existingDay.periods.append(p)
                }
            } else {
                let storedPeriods = makeStoredPeriods(from: day, nightDate: nightDate)
                let storedDay = StoredSleepDay(
                    daysAgo: daysAgo,
                    sleepStart: Int(day.sleepStart),
                    sleepEnd: Int(day.sleepEnd),
                    syncDate: Date(),
                    periods: storedPeriods
                )
                modelContext.insert(storedDay)
            }
        }
        try? modelContext.save()
    }

    private func makeStoredPeriods(from day: SleepDay, nightDate: Date) -> [StoredSleepPeriod] {
        let sleepStartDate = nightDate.addingTimeInterval(TimeInterval(Int(day.sleepStart) * 60))
        var elapsedMinutes = 0
        return day.periods.map { period in
            let start = sleepStartDate.addingTimeInterval(TimeInterval(elapsedMinutes * 60))
            elapsedMinutes += Int(period.minutes)
            return StoredSleepPeriod(type: period.type, minutes: Int(period.minutes), startTimestamp: start)
        }
    }
}
