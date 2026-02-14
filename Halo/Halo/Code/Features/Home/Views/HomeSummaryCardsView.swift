//
//  HomeSummaryCardsView.swift
//  Halo
//
//  Summary cards for activity and metrics on the home screen.
//

import SwiftUI
import SwiftData

struct HomeSummaryCardsView: View {
    /// Last night's sleep duration in minutes (nil if no data).
    var sleepDurationMinutes: Int?
    /// Today's average heart rate in bpm (nil if no data).
    var heartRateAverage: Int?
    /// Activity: steps, distance km, calories. Uses PreviewData when real data not yet available.
    var steps: Int
    var distanceKm: Double
    var calories: Int
    var activityLabel: String

    var body: some View {
        VStack(spacing: 12) {
            activityCard
            HStack(spacing: 12) {
                sleepCard
                heartRateCard
            }
        }
        .padding(.vertical, 4)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.HomeSummary.activity, systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                metricCell(value: "\(steps)", unit: L10n.HomeSummary.steps, color: .cyan)
                metricCell(value: String(format: "%.2f", distanceKm), unit: "km", color: .green)
                metricCell(value: "\(calories)", unit: L10n.HomeSummary.calories, color: .red)
            }
            if !activityLabel.isEmpty {
                Text(activityLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.HomeSummary.sleep, systemImage: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let total = sleepDurationMinutes {
                let h = total / 60
                let m = total % 60
                Text("\(h) h \(m) min")
                    .font(.title2.weight(.semibold))
                Text(L10n.HomeSummary.lastNight)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(L10n.HomeSummary.noData)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.HomeSummary.heartRate, systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let avg = heartRateAverage {
                Text("\(avg) \(L10n.HomeSummary.bpm)")
                    .font(.title2.weight(.semibold))
            } else {
                Text(L10n.HomeSummary.noData)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricCell(value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Default data (PreviewData-backed)

extension HomeSummaryCardsView {
    /// Uses PreviewData for activity; pass sleep and HR from SwiftData when available.
    static func withPreviewActivity(
        sleepDurationMinutes: Int? = nil,
        heartRateAverage: Int? = nil
    ) -> HomeSummaryCardsView {
        let activity = PreviewData.activitySummary
        return HomeSummaryCardsView(
            sleepDurationMinutes: sleepDurationMinutes,
            heartRateAverage: heartRateAverage,
            steps: activity.steps,
            distanceKm: activity.distanceKm,
            calories: activity.calories,
            activityLabel: activity.label
        )
    }
}

#Preview {
    List {
        Section(L10n.HomeSummary.sectionTitle) {
            HomeSummaryCardsView.withPreviewActivity(
                sleepDurationMinutes: 447,
                heartRateAverage: 76
            )
        }
    }
    .listStyle(.insetGrouped)
    .modelContainer(for: [StoredSleepDay.self, StoredHeartRateLog.self], inMemory: true)
}
