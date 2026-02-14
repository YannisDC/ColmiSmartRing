//
//  LocalizedStrings.swift
//  Halo
//
//  Centralized localization keys for user-facing strings.
//

import Foundation

enum L10n {
    enum Device {
        static let sectionTitle = String(localized: "device.section.title")
        static let addRing = String(localized: "device.add_ring")
        static let connect = String(localized: "device.connect")
        static let removeRing = String(localized: "device.remove_ring")
        static let searching = String(localized: "device.searching")
        static let addRingSheetTitle = String(localized: "device.add_ring_sheet.title")
        static let searchingForRing = String(localized: "device.searching_for_ring")
        static let cancel = String(localized: "device.cancel")
        static let defaultRingName = String(localized: "device.default_ring_name")
    }

    enum Settings {
        static let sectionTitle = String(localized: "settings.section.title")
        static let trackingHrv = String(localized: "settings.tracking.hrv")
        static let trackingHeartRate = String(localized: "settings.tracking.heart_rate")
        static let trackingBloodOxygen = String(localized: "settings.tracking.blood_oxygen")
        static let trackingPressure = String(localized: "settings.tracking.pressure")

        static func trackingDisplayName(for setting: RingTrackingSetting) -> String {
            switch setting {
            case .hrv: return trackingHrv
            case .heartRate: return trackingHeartRate
            case .bloodOxygen: return trackingBloodOxygen
            case .pressure: return trackingPressure
            }
        }
    }

    enum Battery {
        static let sectionTitle = String(localized: "battery.section.title")
        static let getStatus = String(localized: "battery.get_status")
        private static let levelFormat = String(localized: "battery.level")
        static func level(_ pct: Int) -> String { String(format: levelFormat, pct) }
        static let chargingYes = String(localized: "battery.charging.yes")
        static let chargingNo = String(localized: "battery.charging.no")
        private static let chargingFormat = String(localized: "battery.charging")
        static func charging(_ value: String) -> String { String(format: chargingFormat, value) }
    }

    enum Sleep {
        static let sectionTitle = String(localized: "sleep.section.title")
        static let requestData = String(localized: "sleep.request_data")
        private static let daysCountFormat = String(localized: "sleep.days_count")
        static func daysCount(_ n: Int) -> String { String(format: daysCountFormat, n) }
        static let otherNights = String(localized: "sleep.other_nights")
        private static let storedNightsFormat = String(localized: "sleep.stored_nights")
        static func storedNights(_ n: Int) -> String { String(format: storedNightsFormat, n) }
        private static let daysAgoFormat = String(localized: "sleep.days_ago")
        static func daysAgo(_ n: Int) -> String { String(format: daysAgoFormat, n) }
        private static let timeQualitiesFormat = String(localized: "Time: %u · Qualities: %u")
        static func timeQualities(time: UInt8, qualities: UInt8) -> String {
            String(format: timeQualitiesFormat, time, qualities)
        }
    }

    enum HeartRate {
        static let sectionTitle = String(localized: "heart_rate.section.title")
        static let logSectionTitle = String(localized: "heart_rate.log.section.title")
        static let getLog = String(localized: "heart_rate.get_log")
        static let streamingStart = String(localized: "heart_rate.streaming.start")
        static let streamingContinue = String(localized: "heart_rate.streaming.continue")
        static let streamingStop = String(localized: "heart_rate.streaming.stop")
    }

    enum SPO2 {
        static let sectionTitle = String(localized: "spo2.section.title")
        static let streamingStart = String(localized: "spo2.streaming.start")
        static let streamingContinue = String(localized: "spo2.streaming.continue")
        static let streamingStop = String(localized: "spo2.streaming.stop")
    }

    enum Debug {
        static let sectionIncrement = String(localized: "debug.section.increment")
        static let sectionBlink = String(localized: "debug.section.blink")
        static let blinkButton = String(localized: "debug.blink_button")
        static let sectionX = String(localized: "debug.section.x")
        private static let sendCommandFormat = String(localized: "debug.send_command")
        static func sendCommand(_ n: Int) -> String { String(format: sendCommandFormat, n) }
        static let xLogSection = String(localized: "debug.x_log.section")
        static let navTitle = String(localized: "Debug")
        static let sendCommandSection = String(localized: "Send command")
        static let commandLabel = String(localized: "Command (0–255)")
        static let commandPlaceholder = String(localized: "e.g. 43")
        static let payloadLabel = String(localized: "Payload (hex)")
        static let payloadPlaceholder = String(localized: "e.g. 01 02 03")
        static let sendButton = String(localized: "Send")
        static let sleepSection = String(localized: "Sleep")
        static let syncSleepBigData = String(localized: "Sync sleep Big Data (39, Colmi service)")
        static let syncSleepToday = String(localized: "Sync sleep today (Commands 68)")
        static let syncSleepYesterday = String(localized: "Sync sleep yesterday (Commands 68)")
        static let syncSleepLegacy = String(localized: "Sync sleep legacy UART (0xBC 0x27)")
        static let showBytesAs = String(localized: "Show bytes as")
        static let clearLog = String(localized: "Clear log")
        static let logHeader = String(localized: "Log")
        private static let logFooterFormat = String(localized: "Last %lld entries. Responses appear when the ring replies.")
        static func logFooter(_ count: Int) -> String { String(format: logFooterFormat, Int64(count)) }
        static let responseLogSection = String(localized: "Response log")
        static let noEntriesYet = String(localized: "No entries yet. Send a command when connected.")
        static let addTag = String(localized: "Add tag")
        static let addTagPlaceholder = String(localized: "Add tag…")
        static let byteFormatHex = String(localized: "Hex")
        static let byteFormatDecimal = String(localized: "Decimal")
    }

    enum HomeSummary {
        static let sectionTitle = String(localized: "home.summary.section.title")
        static let activity = String(localized: "home.summary.activity")
        static let sleep = String(localized: "home.summary.sleep")
        static let heartRate = String(localized: "home.summary.heart_rate")
        static let steps = String(localized: "home.summary.steps")
        static let distance = String(localized: "home.summary.distance")
        static let calories = String(localized: "home.summary.calories")
        static let noData = String(localized: "home.summary.no_data")
        static let bpm = String(localized: "home.summary.bpm")
        static let lastNight = String(localized: "home.summary.last_night")
    }

    enum Tab {
        static let home = String(localized: "tab.home")
        static let activity = String(localized: "tab.activity")
        static let metrics = String(localized: "tab.metrics")
        static let profile = String(localized: "tab.profile")
    }

    enum Activity {
        static let stepsTitle = String(localized: "activity.steps.title")
        static let distanceTitle = String(localized: "activity.distance.title")
        static let caloriesTitle = String(localized: "activity.calories.title")
    }

    enum Profile {
        static let debugSectionTitle = String(localized: "profile.debug.section.title")
    }

    enum Graphs {
        static let navTitle = String(localized: "metrics.screen.title")
        static let sleepSection = String(localized: "Sleep")
        static let totalSleepPerNight = String(localized: "Total sleep per night")
        static let noSleepData = String(localized: "No sleep data yet. Sync from the Main tab.")
        static let noHeartRateData = String(localized: "No heart rate data yet. Sync from the Main tab.")
        static let heartRateSection = String(localized: "Heart rate")
        static let heartRateByDayAvg = String(localized: "Heart rate by day (avg)")
        static let dayPicker = String(localized: "Day")
        static let mostRecent = String(localized: "Most recent")
        static let heartRateIntervals = String(localized: "Heart rate (5‑min intervals)")
        static let noValidReadings = String(localized: "No valid readings for this day")
        static let sampleActivity = String(localized: "Sample data – sync activity from the ring when available.")
        static let sampleHRV = String(localized: "Sample data – sync HRV from the ring when available.")
        static let sampleBloodOxygen = String(localized: "Sample data – sync blood oxygen from the ring when available.")
        static let sampleStress = String(localized: "Sample data – sync stress from the ring when available.")
        static let activitySection = String(localized: "Activity")
        static let hrvSection = String(localized: "HRV")
        static let bloodOxygenSection = String(localized: "Blood Oxygen")
        static let stressSection = String(localized: "Stress")
        static let axisNight = String(localized: "Night")
        static let axisHours = String(localized: "Hours")
        static let axisDay = String(localized: "Day")
        static let axisBPM = String(localized: "BPM")
        private static let sleepSummaryFormat = String(localized: "%lld h %lld min · %@")
        static func sleepSummary(hours: Int, mins: Int, daysAgoText: String) -> String {
            String(format: sleepSummaryFormat, Int64(hours), Int64(mins), daysAgoText)
        }
    }

    enum SleepStage {
        static let totalDuration = String(localized: "Total Duration")
        private static let durationHMFormat = String(localized: "%lld H %lld M")
        static func durationHM(hours: Int, mins: Int) -> String { String(format: durationHMFormat, Int64(hours), Int64(mins)) }
        private static let durationMFormat = String(localized: "%lld M")
        static func durationM(mins: Int) -> String { String(format: durationMFormat, Int64(mins)) }
        private static let rangeFormat = String(localized: "%@–%@")
        static func range(start: String, end: String) -> String { String(format: rangeFormat, start, end) }
        static let awakeTime = String(localized: "Total awake time")
        static let remDuration = String(localized: "REM duration")
        static let lightSleepDuration = String(localized: "Total light sleep duration")
        static let deepSleepDuration = String(localized: "Total deep sleep duration")
        static let axisStart = String(localized: "Start")
        static let axisEnd = String(localized: "End")
        static let axisStage = String(localized: "Stage")
        private static let durationPctFormat = String(localized: "%@ %lld%%")
        static func durationPct(_ durationStr: String, _ pct: Int) -> String { String(format: durationPctFormat, durationStr, Int64(pct)) }
    }

    enum SleepStageLabel {
        static let noData = String(localized: "No data")
        static let error = String(localized: "Error")
        static let lightSleep = String(localized: "Light sleep")
        static let deepSleep = String(localized: "Deep sleep")
        static let rem = String(localized: "REM")
        static let wakeUp = String(localized: "Wake up")
    }

    enum SleepChartKit {
        static let title = String(localized: "Today")
        static let noStages = String(localized: "No sleep stages")
    }

    enum HeartRateGraph {
        static let noDataAvailable = String(localized: "No Data Available")
        static let axisTime = String(localized: "Time")
        static let axisHeartRate = String(localized: "Heart Rate")
    }

    enum A11y {
        static let deviceAddRing = String(localized: "accessibility.device.add_ring")
        static let deviceConnect = String(localized: "accessibility.device.connect")
        static let deviceRemoveRing = String(localized: "accessibility.device.remove_ring")
        static let deviceSearching = String(localized: "Searching")
        static let deviceReconnectHint = String(localized: "Attempts to reconnect to the saved ring")
        static let deviceConnectHint = String(localized: "Tap to connect to this ring")
        private static let settingsToggleFormat = String(localized: "accessibility.settings.toggle")
        static func settingsToggle(_ name: String) -> String { String(format: settingsToggleFormat, name) }
        static let settingsToggleConnectedHint = String(localized: "Toggles tracking on the ring")
        static let settingsToggleDisconnectedHint = String(localized: "Connect the ring to change")
        static let batteryGet = String(localized: "accessibility.battery.get")
        static let batteryGetHint = String(localized: "Requests current battery level from the ring")
        static let sleepRequest = String(localized: "accessibility.sleep.request")
        static let sleepRequestHint = String(localized: "Requests last night sleep data from the ring")
        static let sleepStoredDayHint = String(localized: "Tap to show sleep details")
        static let heartRateGetLog = String(localized: "accessibility.heart_rate.get_log")
        static let heartRateStart = String(localized: "accessibility.heart_rate.start")
        static let heartRateContinue = String(localized: "accessibility.heart_rate.continue")
        static let heartRateStop = String(localized: "accessibility.heart_rate.stop")
        static let spo2Start = String(localized: "accessibility.spo2.start")
        static let spo2Continue = String(localized: "accessibility.spo2.continue")
        static let spo2Stop = String(localized: "accessibility.spo2.stop")
    }
}
