//
//  SleepChartKitView.swift
//  Halo
//
//  Renders a SleepDay using SleepChartKit (Apple-style sleep analysis chart).
//  https://github.com/DanielJamesTronca/SleepChartKit
//

import SwiftUI
import SleepChartKit

/// Converts our SleepDay into SleepChartKit's [SleepSample] and shows SleepChartView.
struct SleepChartKitView: View {
    let day: SleepDay
    var nightDate: Date? = nil

    private var samples: [SleepSample] {
        SleepChartKitAdapter.samples(from: day, nightDate: nightDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.SleepChartKit.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if samples.isEmpty {
                Text(L10n.SleepChartKit.noStages)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                SleepChartView(samples: samples)
                    .frame(height: 170)
            }
        }
    }
}

/// Maps Colmi SleepDay + SleepType to SleepChartKit SleepSample + SleepStage.
enum SleepChartKitAdapter {
    /// Reference date for the night: start of day (midnight) for the night, in local time.
    private static func referenceDate(for day: SleepDay, nightDate: Date?) -> Date {
        let calendar = Calendar.current
        if let nightDate {
            return calendar.startOfDay(for: nightDate)
        }
        let today = calendar.startOfDay(for: Date())
        guard let night = calendar.date(byAdding: .day, value: -Int(day.daysAgo), to: today) else {
            return today
        }
        return night
    }

    /// Start of sleep (bedtime) for this night.
    private static func sleepStartDate(for day: SleepDay, nightDate: Date?) -> Date {
        let ref = referenceDate(for: day, nightDate: nightDate)
        return ref.addingTimeInterval(TimeInterval(Int(day.sleepStart) * 60))
    }

    static func samples(from day: SleepDay, nightDate: Date?) -> [SleepSample] {
        let startOfSleep = sleepStartDate(for: day, nightDate: nightDate)
        return day.segments.map { seg in
            let start = startOfSleep.addingTimeInterval(TimeInterval(seg.start * 60))
            let end = startOfSleep.addingTimeInterval(TimeInterval(seg.end * 60))
            let stage = mapStage(seg.type)
            return SleepSample(stage: stage, startDate: start, endDate: end)
        }
    }

    private static func mapStage(_ type: SleepType) -> SleepStage {
        switch type {
        case .awake: return .awake
        case .core: return .asleepREM
        case .light: return .asleepCore
        case .deep: return .asleepDeep
        case .noData, .error: return .asleepUnspecified
        }
    }
}

#Preview {
    let day = SleepDay(
        daysAgo: 0,
        curDayBytes: 20,
        sleepStart: 23 * 60,
        sleepEnd: 6 * 60 + 27,
        periods: [
            SleepPeriod(type: .light, minutes: 60),
            SleepPeriod(type: .deep, minutes: 45),
            SleepPeriod(type: .core, minutes: 48),
            SleepPeriod(type: .awake, minutes: 5),
            SleepPeriod(type: .deep, minutes: 90)
        ]
    )
    return List {
        SleepChartKitView(day: day)
    }
}
