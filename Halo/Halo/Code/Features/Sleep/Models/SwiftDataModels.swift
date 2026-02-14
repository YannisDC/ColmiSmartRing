//
//  SwiftDataModels.swift
//  Halo
//
//  SwiftData models for persisting sleep and heart rate data from the ring.
//

import Foundation
import SwiftData

// MARK: - Sleep

/// One period within a stored sleep day (e.g. 30 min deep sleep).
@Model
final class StoredSleepPeriod {
    var sleepTypeRaw: Int
    var minutes: Int
    /// Absolute start timestamp for this segment, computed from sleep start + cumulative minutes.
    var startTimestamp: Date

    var sleepType: SleepType {
        get { SleepType(rawValue: UInt8(sleepTypeRaw)) ?? .noData }
        set { sleepTypeRaw = Int(newValue.rawValue) }
    }

    var day: StoredSleepDay?

    init(type: SleepType, minutes: Int, startTimestamp: Date) {
        self.sleepTypeRaw = Int(type.rawValue)
        self.minutes = minutes
        self.startTimestamp = startTimestamp
    }

    init(sleepTypeRaw: Int, minutes: Int, startTimestamp: Date) {
        self.sleepTypeRaw = sleepTypeRaw
        self.minutes = minutes
        self.startTimestamp = startTimestamp
    }
}

/// One day's sleep stored in SwiftData. Maps from Big Data SleepDay.
@Model
final class StoredSleepDay {
    var daysAgo: Int
    var sleepStart: Int
    var sleepEnd: Int
    var syncDate: Date

    @Relationship(deleteRule: .cascade, inverse: \StoredSleepPeriod.day)
    var periods: [StoredSleepPeriod] = []

    init(daysAgo: Int, sleepStart: Int, sleepEnd: Int, syncDate: Date = Date(), periods: [StoredSleepPeriod]) {
        self.daysAgo = daysAgo
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.syncDate = syncDate
        self.periods = periods
        for p in periods {
            p.day = self
        }
    }

    /// Calendar date of this sleep night based on sync date and daysAgo from the packet.
    var sleepDate: Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: syncDate)
        guard let adjusted = calendar.date(byAdding: .day, value: -daysAgo, to: base) else {
            return base
        }
        return adjusted
    }

    /// Convert to the in-memory SleepDay struct for use with existing graph views.
    func toSleepDay() -> SleepDay {
        // Reconstruct timeline in true chronological order based on persisted segment timestamps.
        let storedPeriods = periods
            .sorted { lhs, rhs in
                if lhs.startTimestamp != rhs.startTimestamp { return lhs.startTimestamp < rhs.startTimestamp }
                return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
            }
            .map { SleepPeriod(type: sleepType(from: $0.sleepTypeRaw), minutes: UInt8($0.minutes)) }
        return SleepDay(
            daysAgo: UInt8(daysAgo),
            curDayBytes: 0,
            sleepStart: Int16(sleepStart),
            sleepEnd: Int16(sleepEnd),
            periods: storedPeriods
        )
    }

    private func sleepType(from raw: Int) -> SleepType {
        SleepType(rawValue: UInt8(raw)) ?? .noData
    }
}

// MARK: - Heart rate

/// Stored heart rate log from the ring (one day's 5‑minute readings).
@Model
final class StoredHeartRateLog {
    var timestamp: Date
    /// Start of day for this log (for deduplication: one log per calendar day).
    var dayStart: Date
    var heartRates: [Int]
    var size: Int
    var index: Int
    var range: Int

    init(timestamp: Date, heartRates: [Int], size: Int, index: Int, range: Int) {
        self.timestamp = timestamp
        self.dayStart = Calendar.current.startOfDay(for: timestamp)
        self.heartRates = heartRates
        self.size = size
        self.index = index
        self.range = range
    }

    /// Create from the in-memory HeartRateLog (e.g. after parsing BLE response).
    static func from(_ log: HeartRateLog) -> StoredHeartRateLog {
        StoredHeartRateLog(
            timestamp: log.timestamp,
            heartRates: log.heartRates,
            size: log.size,
            index: log.index,
            range: log.range
        )
    }

    /// Convert to HeartRateLog for use with heartRatesWithTimes() and UI.
    func toHeartRateLog() -> HeartRateLog {
        HeartRateLog(
            heartRates: heartRates,
            timestamp: timestamp,
            size: size,
            index: index,
            range: range
        )
    }
}

// MARK: - Activity / Metrics samples

/// Stored activity sample for one timestamp (steps, distance, calories).
@Model
final class StoredActivitySample {
    var timestamp: Date
    var steps: Int
    var distanceKm: Double
    var calories: Int

    init(timestamp: Date, steps: Int, distanceKm: Double, calories: Int) {
        self.timestamp = timestamp
        self.steps = steps
        self.distanceKm = distanceKm
        self.calories = calories
    }
}

/// Stored HRV sample for one timestamp.
@Model
final class StoredHRVSample {
    var timestamp: Date
    var value: Double

    init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

/// Stored blood oxygen sample for one timestamp.
@Model
final class StoredBloodOxygenSample {
    var timestamp: Date
    var value: Double

    init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

/// Stored stress sample for one timestamp.
@Model
final class StoredStressSample {
    var timestamp: Date
    var value: Double

    init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}
