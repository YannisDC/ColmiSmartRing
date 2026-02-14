import Foundation
import HealthKit

@MainActor
final class AppleHealthSleepWriter {
    private let healthStore = HKHealthStore()
    private var didRequestAuthorization = false

    func writeSleepDays(_ days: [SleepDay], todayStart: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !days.isEmpty else { return }
        do {
            try await requestAuthorizationIfNeeded()
            let samples = makeSamples(days: days, todayStart: todayStart)
            guard !samples.isEmpty else { return }
            try await save(samples)
            print("[HealthKit] Sleep samples written: \(samples.count)")
        } catch {
            print("[HealthKit] Failed to write sleep samples: \(error)")
        }
    }

    private func requestAuthorizationIfNeeded() async throws {
        guard !didRequestAuthorization else { return }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [sleepType], read: []) { [weak self] success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: NSError(domain: "AppleHealthSleepWriter", code: 1))
                    return
                }
                self?.didRequestAuthorization = true
                continuation.resume(returning: ())
            }
        }
    }

    private func save(_ samples: [HKCategorySample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: NSError(domain: "AppleHealthSleepWriter", code: 2))
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func makeSamples(days: [SleepDay], todayStart: Date) -> [HKCategorySample] {
        let calendar = Calendar.current
        var samples: [HKCategorySample] = []
        for day in days {
            guard let nightDate = nightAnchorDate(for: day, todayStart: todayStart, calendar: calendar) else { continue }
            let sleepStartDate = nightDate.addingTimeInterval(TimeInterval(Int(day.sleepStart) * 60))
            var elapsedMinutes = 0
            for (idx, period) in day.periods.enumerated() {
                guard let hkValue = hkSleepValue(for: period.type) else {
                    elapsedMinutes += Int(period.minutes)
                    continue
                }
                let start = sleepStartDate.addingTimeInterval(TimeInterval(elapsedMinutes * 60))
                elapsedMinutes += Int(period.minutes)
                let end = sleepStartDate.addingTimeInterval(TimeInterval(elapsedMinutes * 60))
                guard end > start else { continue }

                let syncId = "halo.sleep.\(Int(day.daysAgo)).\(Int(day.sleepStart)).\(Int(day.sleepEnd)).\(idx).\(period.type.rawValue).\(period.minutes)"
                let metadata: [String: Any] = [
                    HKMetadataKeySyncIdentifier: syncId,
                    // Bump sync version so Health can reconcile previously exported
                    // entries that used an incorrect night anchor.
                    HKMetadataKeySyncVersion: 2
                ]
                let sample = HKCategorySample(
                    type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                    value: hkValue.rawValue,
                    start: start,
                    end: end,
                    metadata: metadata
                )
                samples.append(sample)
            }
        }
        return samples
    }

    private func nightAnchorDate(for day: SleepDay, todayStart: Date, calendar: Calendar) -> Date? {
        // Protocol day reference appears to be the "wakeup day". For overnight sleep
        // where sleepStart > sleepEnd (e.g. 23:00 -> 07:30), anchor bedtime to previous day.
        guard let wakeDate = calendar.date(byAdding: .day, value: -Int(day.daysAgo), to: todayStart) else {
            return nil
        }
        if Int(day.sleepStart) > Int(day.sleepEnd) {
            return calendar.date(byAdding: .day, value: -1, to: wakeDate) ?? wakeDate
        }
        return wakeDate
    }

    private func hkSleepValue(for type: SleepType) -> HKCategoryValueSleepAnalysis? {
        switch type {
        case .awake:
            return .awake
        case .deep:
            return .asleepDeep
        case .core:
            return .asleepREM
        case .light:
            return .asleepCore
        case .noData, .error:
            return nil
        }
    }
}
