//
//  PreviewData.swift
//  Halo
//
//  Sample data for SwiftUI Previews across all measurement chart views.
//

import Foundation
import SwiftUI

// MARK: - Generic time-series point (for Charts)

struct TimeSeriesPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double

    init(time: Date, value: Double) {
        self.time = time
        self.value = value
    }
}

// MARK: - Preview data factory (single day, 24h)

enum PreviewData {
    private static let calendar = Calendar.current

    /// Start of "today" for preview (fixed so previews are stable).
    static var previewReferenceDay: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 11
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    static func hour(of day: Date, hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static func timeAt(day: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    // MARK: - Activity (steps per hour for bar chart)

    /// Steps per hour (00:00–23:00) for one day. Total ~494 to match mockup.
    static var stepsPerHour: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlySteps = [
            0, 0, 0, 0, 0, 12, 45, 120, 80, 65, 0, 0, 30, 0, 42, 0, 0, 28, 42, 0, 0, 0, 0, 0
        ]
        return hourlySteps.enumerated().map { index, steps in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: Double(steps))
        }
    }

    /// Distance in km per hour (same time axis as steps).
    static var distancePerHour: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlyKm: [Double] = [
            0, 0, 0, 0, 0, 0.01, 0.02, 0.05, 0.03, 0.02, 0, 0, 0.01, 0, 0.02, 0, 0, 0.01, 0.02, 0, 0, 0, 0, 0
        ]
        return hourlyKm.enumerated().map { index, km in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: km)
        }
    }

    /// Calories per hour (same time axis).
    static var caloriesPerHour: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlyKcal: [Double] = [
            0, 0, 0, 0, 0, 1, 2, 4, 3, 2, 0, 0, 1, 0, 2, 0, 0, 1, 2, 0, 0, 0, 0, 0
        ]
        return hourlyKcal.enumerated().map { index, kcal in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: kcal)
        }
    }

    /// Weekly average steps per hour (same time axis as stepsPerHour, for comparison line).
    static var stepsPerHourWeeklyAverage: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlySteps: [Double] = [
            0, 0, 0, 0, 0, 8, 35, 95, 65, 52, 0, 0, 24, 0, 34, 0, 0, 22, 34, 0, 0, 0, 0, 0
        ]
        return hourlySteps.enumerated().map { index, steps in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: steps)
        }
    }

    /// Weekly average distance per hour (same time axis, for comparison line).
    static var distancePerHourWeeklyAverage: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlyKm: [Double] = [
            0, 0, 0, 0, 0, 0.008, 0.016, 0.04, 0.024, 0.016, 0, 0, 0.008, 0, 0.016, 0, 0, 0.008, 0.016, 0, 0, 0, 0, 0
        ]
        return hourlyKm.enumerated().map { index, km in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: km)
        }
    }

    /// Weekly average calories per hour (same time axis, for comparison line).
    static var caloriesPerHourWeeklyAverage: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let hourlyKcal: [Double] = [
            0, 0, 0, 0, 0, 0.8, 1.6, 3.2, 2.4, 1.6, 0, 0, 0.8, 0, 1.6, 0, 0, 0.8, 1.6, 0, 0, 0, 0, 0
        ]
        return hourlyKcal.enumerated().map { index, kcal in
            TimeSeriesPoint(time: hour(of: day, hour: index), value: kcal)
        }
    }

    /// Activity summary for dashboard (totals + score).
    static var activitySummary: (steps: Int, distanceKm: Double, calories: Int, score: Int, label: String) {
        let steps = Int(PreviewData.stepsPerHour.map(\.value).reduce(0, +))
        let km = PreviewData.distancePerHour.map(\.value).reduce(0, +)
        let kcal = Int(PreviewData.caloriesPerHour.map(\.value).reduce(0, +))
        return (steps, km, kcal, 2, "Lack of exercise")
    }

    // MARK: - Heart rate (every 30 min, bpm)

    static var heartRatePoints: [HeartRateDataPoint] {
        let day = previewReferenceDay
        let bpmValues: [Int] = [
            62, 60, 58, 65, 70, 72, 75, 76, 78, 76, 74, 72, 70, 68, 72, 75, 76, 78, 95, 79, 76, 72, 68, 65,
            64, 62, 60, 58, 60, 62, 65, 68, 70, 72, 74, 76, 76, 74, 72, 70, 68, 66, 64, 62, 60, 58, 60, 62
        ]
        return (0..<Swift.min(48, bpmValues.count)).map { i in
            let (h, m) = (i / 2, (i % 2) * 30)
            let t = timeAt(day: day, hour: h, minute: m)
            return HeartRateDataPoint(heartRate: bpmValues[i], time: t)
        }
    }

    // MARK: - HRV (ms, 0–178 scale)

    static var hrvPoints: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let msValues: [Double] = [
            42, 48, 45, 50, 52, 48, 46, 44, 42, 40, 45, 48, 50, 52, 55, 48, 46, 44, 42, 48, 50, 52, 48, 46,
            44, 42, 45, 48, 50, 48, 46, 44, 42, 48, 50, 52, 48, 46, 44, 42, 45, 48, 50, 48, 46, 44, 42, 48
        ]
        return (0..<Swift.min(48, msValues.count)).map { i in
            let (h, m) = (i / 2, (i % 2) * 30)
            return TimeSeriesPoint(time: timeAt(day: day, hour: h, minute: m), value: msValues[i])
        }
    }

    // MARK: - Blood oxygen (%, 80–100)

    static var bloodOxygenPoints: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let pctValues: [Double] = [
            98, 99, 98, 99, 98, 97, 98, 99, 99, 98, 99, 98, 97, 98, 99, 98, 99, 98, 99, 99, 98, 97, 98, 99,
            98, 99, 98, 99, 98, 97, 98, 99, 99, 98, 99, 98, 97, 98, 99, 98, 99, 98, 99, 99, 98, 97, 98, 99
        ]
        return (0..<Swift.min(48, pctValues.count)).map { i in
            let (h, m) = (i / 2, (i % 2) * 30)
            return TimeSeriesPoint(time: timeAt(day: day, hour: h, minute: m), value: pctValues[i])
        }
    }

    // MARK: - Stress (0–100, status "Normal" etc.)

    static var stressPoints: [TimeSeriesPoint] {
        let day = previewReferenceDay
        let values: [Double] = [
            35, 38, 40, 42, 45, 44, 42, 40, 38, 39, 41, 45, 47, 45, 42, 40, 38, 39, 44, 45, 44, 42, 40, 38,
            36, 34, 32, 35, 39, 42, 45, 44, 42, 40, 38, 39, 41, 45, 47, 45, 42, 40, 38, 39, 44, 45, 44, 42
        ]
        return (0..<Swift.min(48, values.count)).map { i in
            let (h, m) = (i / 2, (i % 2) * 30)
            return TimeSeriesPoint(time: timeAt(day: day, hour: h, minute: m), value: values[i])
        }
    }

    // MARK: - Sleep (SleepDay for stage timeline)

    static var sleepDay: SleepDay {
        SleepDay(
            daysAgo: 0,
            curDayBytes: 20,
            sleepStart: 23 * 60,
            sleepEnd: 6 * 60 + 27,
            periods: [
                SleepPeriod(type: .light, minutes: 60),
                SleepPeriod(type: .deep, minutes: 45),
                SleepPeriod(type: .core, minutes: 48),
                SleepPeriod(type: .light, minutes: 120),
                SleepPeriod(type: .awake, minutes: 5),
                SleepPeriod(type: .deep, minutes: 90)
            ]
        )
    }
}
