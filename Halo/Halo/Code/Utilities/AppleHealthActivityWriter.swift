import Foundation
import HealthKit

@MainActor
final class AppleHealthActivityWriter {
    private let healthStore = HKHealthStore()
    private var didRequestAuthorization = false

    func writeActivitySample(timestamp: Date, steps: Int, calories: Int) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard steps > 0 || calories > 0 else { return }

        do {
            try await requestAuthorizationIfNeeded()
            let samples = makeSamples(timestamp: timestamp, steps: steps, calories: calories)
            guard !samples.isEmpty else { return }
            try await save(samples)
            debugPrint("[HealthKit] Activity samples written: \(samples.count)")
        } catch {
            debugPrint("[HealthKit] Failed to write activity samples: \(error)")
        }
    }

    private func requestAuthorizationIfNeeded() async throws {
        guard !didRequestAuthorization else { return }
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [stepType, energyType], read: []) { [weak self] success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: NSError(domain: "AppleHealthActivityWriter", code: 1))
                    return
                }
                self?.didRequestAuthorization = true
                continuation.resume(returning: ())
            }
        }
    }

    private func save(_ samples: [HKQuantitySample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: NSError(domain: "AppleHealthActivityWriter", code: 2))
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func makeSamples(timestamp: Date, steps: Int, calories: Int) -> [HKQuantitySample] {
        let end = timestamp.addingTimeInterval(15 * 60)
        var samples: [HKQuantitySample] = []

        if steps > 0 {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(steps))
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "halo.activity.steps.\(Int(timestamp.timeIntervalSince1970))",
                HKMetadataKeySyncVersion: 1
            ]
            samples.append(
                HKQuantitySample(type: stepType, quantity: quantity, start: timestamp, end: end, metadata: metadata)
            )
        }

        if calories > 0 {
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: Double(calories))
            let metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: "halo.activity.kcal.\(Int(timestamp.timeIntervalSince1970))",
                HKMetadataKeySyncVersion: 1
            ]
            samples.append(
                HKQuantitySample(type: energyType, quantity: quantity, start: timestamp, end: end, metadata: metadata)
            )
        }

        return samples
    }
}
