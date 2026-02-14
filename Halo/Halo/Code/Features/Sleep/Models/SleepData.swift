//
//  SleepData.swift
//  Halo
//
//  Sleep data from Commands (ID 68) and Big Data (ID 39) protocols.
//

import Foundation
import SwiftUI

// MARK: - Commands protocol (16-byte, Nordic UART)
struct SleepData {
    /// Year (device uses % 2000, e.g. 25 = 2025)
    let year: Int
    /// Month (1–12)
    let month: Int
    /// Day of month (1–31)
    let day: Int
    /// Time field (exact meaning TBD in API; may be duration or time)
    let time: UInt8
    /// Sleep quality / stage data (format TBD in API)
    let sleepQualities: UInt8
    /// Requested day offset (0 = today, 1 = yesterday, etc.)
    let dayOffset: Int

    var date: Date? {
        var c = DateComponents()
        c.year = 2000 + year
        c.month = month
        c.day = day
        c.hour = 0
        c.minute = 0
        c.second = 0
        return Calendar.current.date(from: c)
    }
}

// MARK: - Big Data protocol (Colmi service, variable length)

/// Sleep type from ring (Big Data Sleep ID 39).
enum SleepType: UInt8 {
    case noData = 0
    case error = 1
    case light = 2
    case deep = 3
    /// Value 4: core sleep (some firmware/APIs use this for REM or “core” stage).
    case core = 4
    case awake = 5
}

/// One period within a day (e.g. 30 min deep sleep).
struct SleepPeriod: Sendable {
    let type: SleepType
    let minutes: UInt8
}

/// One day's sleep: start/end and list of periods.
struct SleepDay: Sendable {
    /// Days ago (0 = today, 1 = yesterday, …).
    let daysAgo: UInt8
    /// Byte length for this day's payload after [daysAgo, curDayBytes].
    let curDayBytes: UInt8
    /// Sleep start: minutes after midnight.
    let sleepStart: Int16
    /// Sleep end: minutes after midnight.
    let sleepEnd: Int16
    let periods: [SleepPeriod]

    /// Time in bed in minutes derived from sleepStart/sleepEnd (handles overnight: end < start).
    var totalDurationMinutes: Int {
        let start = Int(sleepStart)
        let end = Int(sleepEnd)
        if end <= start {
            return (24 * 60 - start) + end
        }
        return end - start
    }

    /// Time asleep in minutes (time in bed minus awake stage minutes).
    var timeAsleepMinutes: Int {
        let awakeMinutes = periods.reduce(0) { partial, period in
            partial + (period.type == .awake ? Int(period.minutes) : 0)
        }
        return max(0, totalDurationMinutes - awakeMinutes)
    }

    /// Timeline segments for graphing: (start minute from sleep start, end minute, type).
    var segments: [(start: Int, end: Int, type: SleepType)] {
        var result: [(Int, Int, SleepType)] = []
        var cursor = 0
        for p in periods {
            let len = Int(p.minutes)
            result.append((cursor, cursor + len, p.type))
            cursor += len
        }
        return result
    }

    /// Minutes per stage (for summary bars).
    func minutesPerStage() -> [SleepType: Int] {
        var map: [SleepType: Int] = [.noData: 0, .error: 0, .light: 0, .deep: 0, .core: 0, .awake: 0]
        for p in periods {
            map[p.type, default: 0] += Int(p.minutes)
        }
        return map
    }
}

/// Full Big Data sleep response (dataId 39).
struct BigDataSleepData: Sendable {
    let sleepDays: UInt8
    let days: [SleepDay]
}

// MARK: - Big Data sleep parser

enum BigDataSleepParser {
    private static let bigDataMagic: UInt8 = 188
    private static let sleepDataId: UInt8 = 39

    /// Parse Big Data payload for sleep (after 6-byte header). Payload = sleepDays + SleepDay[].
    static func parseSleepPayload(_ bytes: [UInt8]) -> BigDataSleepData? {
        guard bytes.count >= 1 else { return nil }
        let sleepDays = bytes[0]
        var days: [SleepDay] = []
        var offset = 1
        for _ in 0..<sleepDays {
            // Day framing from observed packets:
            // [daysAgo, curDayBytes, sleepStart(LE), sleepEnd(LE), periods...]
            // where curDayBytes counts bytes AFTER [daysAgo, curDayBytes].
            guard offset + 2 <= bytes.count else { break }
            let daysAgo = bytes[offset]
            let curDayBytes = bytes[offset + 1]
            let dayStart = offset
            let dayPayloadStart = offset + 2
            let dayPayloadLen = Int(curDayBytes)
            let dayPayloadEnd = dayPayloadStart + dayPayloadLen
            guard dayPayloadLen >= 4, dayPayloadEnd <= bytes.count else { break }

            let sleepStart = Int16(bitPattern: UInt16(bytes[offset + 2]) | (UInt16(bytes[offset + 3]) << 8))
            let sleepEnd = Int16(bitPattern: UInt16(bytes[offset + 4]) | (UInt16(bytes[offset + 5]) << 8))
            offset = dayPayloadStart + 4

            let periodBytes = dayPayloadLen - 4
            var periods: [SleepPeriod] = []
            for _ in 0..<(periodBytes / 2) {
                guard offset + 2 <= dayPayloadEnd else { break }
                let typeRaw = bytes[offset]
                let minutes = bytes[offset + 1]
                offset += 2
                periods.append(SleepPeriod(type: SleepType(rawValue: typeRaw) ?? .noData, minutes: minutes))
            }

            // Skip any padding/unknown trailing bytes declared by curDayBytes.
            offset = dayPayloadEnd
            days.append(SleepDay(daysAgo: daysAgo, curDayBytes: curDayBytes, sleepStart: sleepStart, sleepEnd: sleepEnd, periods: periods))
        }
        return BigDataSleepData(sleepDays: sleepDays, days: days)
    }
}
