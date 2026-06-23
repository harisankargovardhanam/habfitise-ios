import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private(set) var latestEnergyScore: Int?

    private init() {}

    func requestAuthorization(isPro: Bool) async throws {
        guard isPro else {
            throw HealthKitServiceError.proRequired
        }
        guard isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchTodayStepCount() async throws -> Double {
        guard isAvailable else { return 0 }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            store.execute(query)
        }
    }
}

enum HealthKitServiceError: LocalizedError {
    case proRequired
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .proRequired:
            "Apple Health sync requires \(AppConstants.proProductName)."
        case .notAvailable:
            "HealthKit is not available on this device."
        }
    }
}
