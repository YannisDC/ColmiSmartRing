import SwiftUI
import SwiftData
import SleepChartKit

struct HomeScreenView: View {
    @Bindable var ringSessionManager: RingSessionManager
    @Query(sort: \StoredSleepDay.syncDate, order: .reverse) private var storedSleepDays: [StoredSleepDay]
    @Query(sort: \StoredHeartRateLog.timestamp, order: .reverse) private var storedHeartRateLogs: [StoredHeartRateLog]
    @Query(sort: \StoredActivitySample.timestamp, order: .reverse) private var storedActivitySamples: [StoredActivitySample]

    private var latestSleepDurationMinutes: Int? {
        storedSleepDays.first.map { $0.toSleepDay().totalDurationMinutes }
    }

    private var todayHeartRateAverage: Int? {
        guard let log = storedHeartRateLogs.first else { return nil }
        let withTimes = (try? log.toHeartRateLog().heartRatesWithTimes()) ?? []
        let valid = withTimes.map(\.0).filter { $0 > 0 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / valid.count
    }

    private var latestActivity: (steps: Int, distanceKm: Double, calories: Int, label: String)? {
        guard let sample = storedActivitySamples.first else { return nil }
        return (sample.steps, sample.distanceKm, sample.calories, "")
    }

    private var todaySleepRecord: StoredSleepDay? {
        let today = Calendar.current.startOfDay(for: Date())
        return storedSleepDays.first { Calendar.current.isDate($0.sleepDate, inSameDayAs: today) }
    }

    private var todaySleepSamples: [SleepSample] {
        guard let record = todaySleepRecord else { return [] }
        return SleepChartKitAdapter.samples(from: record.toSleepDay(), nightDate: record.sleepDate)
    }

    private var todaySleepTotalMinutes: Int? {
        todaySleepRecord?.toSleepDay().totalDurationMinutes
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.HomeSummary.sectionTitle) {
                    HomeSummaryCardsView(
                        sleepDurationMinutes: latestSleepDurationMinutes,
                        heartRateAverage: todayHeartRateAverage,
                        steps: latestActivity?.steps ?? PreviewData.activitySummary.steps,
                        distanceKm: latestActivity?.distanceKm ?? PreviewData.activitySummary.distanceKm,
                        calories: latestActivity?.calories ?? PreviewData.activitySummary.calories,
                        activityLabel: latestActivity?.label ?? PreviewData.activitySummary.label
                    )
                }
                Section(L10n.Sleep.sectionTitle) {
                    if todaySleepSamples.isEmpty {
                        Text(L10n.Graphs.noSleepData)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 12) {
                            SleepCircularChartView(samples: todaySleepSamples)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                            homeSleepLegend
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Tab.home)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var homeSleepLegend: some View {
        let items: [(label: String, color: Color)] = [
            (L10n.SleepStageLabel.wakeUp, .orange),
            (L10n.SleepStageLabel.rem, .gray),
            (L10n.SleepStageLabel.lightSleep, Color.purple.opacity(0.6)),
            (L10n.SleepStageLabel.deepSleep, .purple)
        ]
        return VStack(alignment: .leading, spacing: 8) {
            if let total = todaySleepTotalMinutes {
                HStack {
                    Text(L10n.SleepStage.totalDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.SleepStage.durationHM(hours: total / 60, mins: total % 60))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            HStack(spacing: 12) {
                ForEach(items, id: \.label) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeScreenView(ringSessionManager: RingSessionManager())
        .modelContainer(
            for: [
                StoredSleepDay.self,
                StoredSleepPeriod.self,
                StoredHeartRateLog.self,
                StoredActivitySample.self
            ],
            inMemory: true
        )
}
