import Foundation
import SwiftData

@MainActor
final class RingDataPersistenceCoordinator {
    private let modelContext: ModelContext
    private unowned let ringSessionManager: RingSessionManager

    private var hrvSeriesAccumulator = SplitSeriesPacketParser.SeriesAccumulator()
    private var stressSeriesAccumulator = SplitSeriesPacketParser.SeriesAccumulator()
    private let healthSleepWriter = AppleHealthSleepWriter()

    private static let logDateFormatter = ISO8601DateFormatter()

    init(modelContext: ModelContext, ringSessionManager: RingSessionManager) {
        self.modelContext = modelContext
        self.ringSessionManager = ringSessionManager
    }

    func start() {
        ringSessionManager.bigDataSleepPersistenceCallback = { [weak self] sleepData in
            guard let self else { return }
            self.persistSleepData(sleepData)
        }
        ringSessionManager.heartRateLogPersistenceCallback = { [weak self] heartRateLog in
            guard let self else { return }
            self.persistHeartRateLog(heartRateLog)
        }
        ringSessionManager.activityDataPacketPersistenceCallback = { [weak self] packet in
            guard let self else { return }
            self.consumeActivityPacket(packet)
        }
        ringSessionManager.hrvDataPacketPersistenceCallback = { [weak self] packet in
            guard let self else { return }
            self.consumeSplitSeriesPacket(packet, isHRV: true)
        }
        ringSessionManager.pressureDataPacketPersistenceCallback = { [weak self] packet in
            guard let self else { return }
            self.consumeSplitSeriesPacket(packet, isHRV: false)
        }
        ringSessionManager.bigDataBloodOxygenPayloadPersistenceCallback = { [weak self] payload in
            guard let self else { return }
            let decoded = self.decodeBloodOxygenPayload(payload)
            self.persistBloodOxygenSeries(decoded)
        }
    }

    // MARK: - Sleep

    private func persistSleepData(_ bigData: BigDataSleepData) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var insertedDays = 0
        var updatedDays = 0

        for day in bigData.days {
            let daysAgo = Int(day.daysAgo)
            let nightDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let descriptor = FetchDescriptor<StoredSleepDay>(
                predicate: #Predicate<StoredSleepDay> { $0.daysAgo == daysAgo }
            )
            let existing = (try? modelContext.fetch(descriptor))?.first
            if let existingDay = existing {
                updatedDays += 1
                existingDay.sleepStart = Int(day.sleepStart)
                existingDay.sleepEnd = Int(day.sleepEnd)
                existingDay.syncDate = Date()
                for period in existingDay.periods {
                    modelContext.delete(period)
                }
                existingDay.periods = []
                let newPeriods = makeStoredPeriods(from: day, nightDate: nightDate)
                for period in newPeriods {
                    period.day = existingDay
                    modelContext.insert(period)
                    existingDay.periods.append(period)
                }
            } else {
                insertedDays += 1
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

        debugPrint("[AutoPersist] Sleep save requested. insertedDays=\(insertedDays) updatedDays=\(updatedDays)")
        if saveContext(tag: "Sleep") {
            Task { @MainActor in
                await healthSleepWriter.writeSleepDays(bigData.days, todayStart: today)
            }
        }
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

    // MARK: - Heart Rate

    private func persistHeartRateLog(_ log: HeartRateLog) {
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
            modelContext.insert(StoredHeartRateLog.from(log))
            action = "INSERT"
        }

        debugPrint("[AutoPersist] Heart rate log save requested. action=\(action) dayStart=\(formatDate(dayStart))")
        _ = saveContext(tag: "HeartRate")
    }

    // MARK: - Activity

    private func consumeActivityPacket(_ packet: [UInt8]) {
        guard packet.count >= 11, packet[0] == 67 else { return }
        let timeSlot = Int(packet[4])
        // Firmware observed in logs uses quarter-hour slots for SportsData time:
        // 32 => 08:00, 44 => 11:00. Some variants still send 0...23.
        let hour: Int
        let minute: Int
        if timeSlot <= 23 {
            hour = timeSlot
            minute = 0
        } else {
            hour = max(0, min(23, timeSlot / 4))
            minute = (timeSlot % 4) * 15
        }

        // Observed SportsData payload variant:
        // - steps at bytes 9..10
        // - distance meters at bytes 11..12
        // - bytes 5..8 often contain larger cumulative counters not suitable for the per-slot graph
        let steps = Int(packet[9]) | (Int(packet[10]) << 8)
        let distanceMeters = Int(packet[11]) | (Int(packet[12]) << 8)
        let distanceKm = Double(distanceMeters) / 1000.0
        let packetCalories = Int(packet[5]) | (Int(packet[6]) << 8)
        let estimatedCalories = Int(round(Double(steps) * 0.04))
        let calories = (1...50).contains(packetCalories) ? packetCalories : estimatedCalories

        // Ignore metadata/empty activity packets.
        guard steps > 0 || distanceMeters > 0 || calories > 0 else {
            debugPrint("[AutoPersist] Activity packet ignored (empty): \(packet)")
            return
        }

        let timestamp = todayAt(hour: hour, minute: minute)

        let descriptor = FetchDescriptor<StoredActivitySample>(
            predicate: #Predicate<StoredActivitySample> { $0.timestamp == timestamp }
        )
        let action: String
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.steps = steps
            existing.distanceKm = distanceKm
            existing.calories = calories
            action = "UPDATE"
        } else {
            modelContext.insert(StoredActivitySample(timestamp: timestamp, steps: steps, distanceKm: distanceKm, calories: calories))
            action = "INSERT"
        }

        debugPrint("[AutoPersist] Activity save requested. action=\(action) ts=\(formatDate(timestamp)) steps=\(steps) kcal=\(calories) distKm=\(distanceKm)")
        _ = saveContext(tag: "Activity")
    }

    private func todayAt(hour: Int, minute: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }

    // MARK: - HRV / Stress split-series

    private func consumeSplitSeriesPacket(_ packet: [UInt8], isHRV: Bool) {
        let series: [TimeSeriesPoint]?
        if isHRV {
            series = hrvSeriesAccumulator.consume(packet)
        } else {
            series = stressSeriesAccumulator.consume(packet)
        }
        guard let series else { return }

        if isHRV {
            persistHRVSeries(series)
        } else {
            persistStressSeries(series)
        }
    }

    private func persistHRVSeries(_ series: [TimeSeriesPoint]) {
        let existingSamples = (try? modelContext.fetch(FetchDescriptor<StoredHRVSample>())) ?? []
        var inserted = 0
        var updated = 0
        for point in series {
            if let existing = existingSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated += 1
            } else {
                modelContext.insert(StoredHRVSample(timestamp: point.time, value: point.value))
                inserted += 1
            }
        }
        debugPrint("[AutoPersist] HRV save requested. inserted=\(inserted) updated=\(updated) total=\(series.count)")
        _ = saveContext(tag: "HRV")
    }

    private func persistStressSeries(_ series: [TimeSeriesPoint]) {
        let existingSamples = (try? modelContext.fetch(FetchDescriptor<StoredStressSample>())) ?? []
        var inserted = 0
        var updated = 0
        for point in series {
            if let existing = existingSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated += 1
            } else {
                modelContext.insert(StoredStressSample(timestamp: point.time, value: point.value))
                inserted += 1
            }
        }
        debugPrint("[AutoPersist] Stress save requested. inserted=\(inserted) updated=\(updated) total=\(series.count)")
        _ = saveContext(tag: "Stress")
    }

    // MARK: - Blood oxygen

    private func decodeBloodOxygenPayload(_ payload: [UInt8]) -> [TimeSeriesPoint] {
        guard payload.count >= 4 else { return [] }

        // Payloads observed on this firmware are mostly packed hourly min/max bytes.
        // Use a pragmatic decode for current day instead of interpreting payload[1] as daysAgo
        // (which produced implausible dates and invisible graph data).
        let sampleBytes = Array(payload.dropFirst())
        return decodeBloodOxygenHourlyPairs(sampleBytes: sampleBytes, daysAgo: 0)
    }

    private func decodeBloodOxygenHourlyPairs(sampleBytes: [UInt8], daysAgo: Int) -> [TimeSeriesPoint] {
        var points: [TimeSeriesPoint] = []
        var hour = 0
        var i = 0
        while i + 1 < sampleBytes.count, hour < 24 {
            let minV = Double(sampleBytes[i])
            let maxV = Double(sampleBytes[i + 1])
            let avg = (minV + maxV) / 2.0
            if avg > 0 {
                points.append(TimeSeriesPoint(time: dayAtHour(daysAgo: daysAgo, hour: hour), value: avg))
            }
            i += 2
            hour += 1
        }
        return points
    }

    private func persistBloodOxygenSeries(_ series: [TimeSeriesPoint]) {
        guard !series.isEmpty else { return }
        let existingSamples = (try? modelContext.fetch(FetchDescriptor<StoredBloodOxygenSample>())) ?? []
        var inserted = 0
        var updated = 0
        for point in series {
            if let existing = existingSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated += 1
            } else {
                modelContext.insert(StoredBloodOxygenSample(timestamp: point.time, value: point.value))
                inserted += 1
            }
        }
        debugPrint("[AutoPersist] Blood oxygen save requested. inserted=\(inserted) updated=\(updated) total=\(series.count)")
        _ = saveContext(tag: "BloodOxygen")
    }

    private func dayAtHour(daysAgo: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return calendar.date(bySettingHour: max(0, min(23, hour)), minute: 0, second: 0, of: day) ?? day
    }

    // MARK: - Shared

    @discardableResult
    private func saveContext(tag: String) -> Bool {
        do {
            try modelContext.save()
            debugPrint("[AutoPersist] SwiftData save SUCCESS (\(tag))")
            return true
        } catch {
            debugPrint("[AutoPersist] SwiftData save FAILED (\(tag)): \(error)")
            return false
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.logDateFormatter.string(from: date)
    }
}
