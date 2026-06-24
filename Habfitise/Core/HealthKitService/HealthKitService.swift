import Foundation
import HealthKit
import UIKit

enum HomeHealthConnectionState: Equatable {
    case unavailable
    case notConnected
    case connected
    case denied
}

struct HomeHealthSnapshot: Equatable {
    var steps: Int
    var stepGoal: Int
    var activeEnergyKcal: Int
    var exerciseMinutes: Int
    var distanceMeters: Double

    static let empty = HomeHealthSnapshot(
        steps: 0,
        stepGoal: AppConstants.Health.defaultStepGoal,
        activeEnergyKcal: 0,
        exerciseMinutes: 0,
        distanceMeters: 0
    )

    var stepProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(steps) / Double(stepGoal), 1)
    }

    var formattedDistance: String {
        let km = distanceMeters / 1_000
        if km >= 1 {
            return String(format: "%.1f km", km)
        }
        return String(format: "%.0f m", distanceMeters)
    }

    var hasAnyMovementData: Bool {
        steps > 0 || activeEnergyKcal > 0 || exerciseMinutes > 0 || distanceMeters > 0
    }
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var stepObserverQuery: HKObserverQuery?
    private var isMonitoringStepCount = false

    private(set) var latestEnergyScore: Int?
    private(set) var lastReadError: String?

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.healthKitAuthorizationRequested)
    }

    func connectionState() -> HomeHealthConnectionState {
        guard isAvailable else { return .unavailable }
        guard hasRequestedAuthorization else { return .notConnected }
        if lastReadError != nil { return .denied }
        return .connected
    }

    func setStepGoal(_ goal: Int) {
        let clamped = max(1_000, min(goal, 30_000))
        UserDefaults.standard.set(clamped, forKey: AppConstants.UserDefaultsKeys.dailyStepGoal)
    }

    func resetAuthorizationFlag() {
        UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.healthKitAuthorizationRequested)
        lastReadError = nil
        stopStepCountMonitoring()
    }

    func startStepCountMonitoring() {
        guard isAvailable, hasRequestedAuthorization else { return }
        guard !isMonitoringStepCount else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, _, error in
            guard error == nil else { return }
            Task { @MainActor in
                NotificationCenter.default.post(name: .healthKitStepsDidUpdate, object: nil)
            }
        }
        stepObserverQuery = query
        isMonitoringStepCount = true
        store.execute(query)
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }

    func stopStepCountMonitoring() {
        if let stepObserverQuery {
            store.stop(stepObserverQuery)
            self.stepObserverQuery = nil
        }
        isMonitoringStepCount = false
    }

    func syncAuthorizationRequestStatus() async {
        guard isAvailable else { return }

        let readTypes = Set(Self.readObjectTypes)
        let status = await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }

        if status == .unnecessary {
            markAuthorizationRequested()
        }
    }

    func requestAuthorization(isPro: Bool) async throws {
        guard isPro else {
            throw HealthKitServiceError.proRequired
        }
        guard isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        lastReadError = nil
        let readTypes = Set(Self.readObjectTypes)
        let shareTypes = Set(Self.shareObjectTypes)
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        markAuthorizationRequested()

        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
        }
    }

    func saveWorkoutSession(_ session: WorkoutSession) async {
        guard isAvailable, hasRequestedAuthorization else { return }

        let start = session.startedAt
        let end = session.completedAt ?? start.addingTimeInterval(TimeInterval(max(session.durationSeconds, 60)))
        let activityType = hkActivityType(for: session.type)
        let calories = session.totalCalories ?? 0
        let energy = HKQuantity(
            unit: .kilocalorie(),
            doubleValue: Double(max(calories, 0))
        )

        let workout = HKWorkout(
            activityType: activityType,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: calories > 0 ? energy : nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: AppConstants.appName,
                "VAYAWorkoutName": session.name
            ]
        )

        do {
            try await store.save(workout)
        } catch {
            // Health write is best-effort; local session remains source of truth.
        }
    }

    func fetchWeeklySteps(calendar: Calendar = .current) async -> [Int] {
        guard isAvailable, hasRequestedAuthorization else {
            return Array(repeating: 0, count: 7)
        }

        let today = calendar.startOfDay(for: .now)
        var results: [Int] = []

        for offset in (0..<7).reversed() {
            guard
                let day = calendar.date(byAdding: .day, value: offset - 6, to: today),
                let next = calendar.date(byAdding: .day, value: 1, to: day)
            else {
                results.append(0)
                continue
            }

            let steps = await fetchStepCount(from: day, to: next)
            results.append(steps)
        }

        return results
    }

    func fetchTodaySnapshot() async -> HomeHealthSnapshot {
        guard isAvailable, hasRequestedAuthorization else {
            return .empty
        }

        lastReadError = nil
        let stepGoal = resolvedStepGoal()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = Date()

        async let steps = fetchStepCount(from: start, to: end)
        async let energy = fetchSum(for: .activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let exercise = fetchSum(for: .appleExerciseTime, unit: .minute(), from: start, to: end)
        async let distance = fetchSum(for: .distanceWalkingRunning, unit: .meter(), from: start, to: end)

        let snapshot = HomeHealthSnapshot(
            steps: await steps,
            stepGoal: stepGoal,
            activeEnergyKcal: Int((await energy).rounded()),
            exerciseMinutes: Int((await exercise).rounded()),
            distanceMeters: await distance
        )

        if !snapshot.hasAnyMovementData, lastReadError != nil {
            // Authorization likely denied for read types.
        }

        updateEnergyScore(activeEnergyKcal: snapshot.activeEnergyKcal)
        return snapshot
    }

    // MARK: - Private

    private func markAuthorizationRequested() {
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.healthKitAuthorizationRequested)
    }

    private static var readObjectTypes: [HKObjectType] {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning
        ]
        return identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
    }

    private static var shareObjectTypes: [HKSampleType] {
        [HKObjectType.workoutType()]
    }

    private func hkActivityType(for type: WorkoutType) -> HKWorkoutActivityType {
        switch type {
        case .weights: .traditionalStrengthTraining
        case .cardio: .running
        case .bodyweight: .functionalStrengthTraining
        case .hiit: .highIntensityIntervalTraining
        case .flexibility: .flexibility
        }
    }

    /// Primary step read — HKStatisticsCollectionQuery matches Apple Health "Today" aggregation.
    private func fetchStepCount(from start: Date, to end: Date) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let collectionResult = await fetchStepCountViaCollection(stepType: stepType, from: start, to: end)
        if collectionResult > 0 { return collectionResult }

        let statisticsResult = await fetchSumWithAuthCheck(
            for: .stepCount,
            unit: .count(),
            from: start,
            to: end
        )
        if statisticsResult.value > 0 { return Int(statisticsResult.value) }

        let sampleResult = await fetchStepCountViaSamples(stepType: stepType, from: start, to: end)
        return sampleResult
    }

    private func fetchStepCountViaCollection(stepType: HKQuantityType, from start: Date, to end: Date) async -> Int {
        await withCheckedContinuation { continuation in
            let interval = DateComponents(day: 1)
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { [weak self] _, collection, error in
                if let error {
                    let message = Self.authorizationErrorMessage(from: error)
                    Task { @MainActor [weak self] in
                        if let message { self?.lastReadError = message }
                        continuation.resume(returning: 0)
                    }
                    return
                }

                var total = 0
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        total += Int(quantity.doubleValue(for: .count()))
                    }
                }
                continuation.resume(returning: total)
            }

            store.execute(query)
        }
    }

    private func fetchStepCountViaSamples(stepType: HKQuantityType, from start: Date, to end: Date) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                if let error {
                    let message = Self.authorizationErrorMessage(from: error)
                    Task { @MainActor [weak self] in
                        if let message { self?.lastReadError = message }
                        continuation.resume(returning: 0)
                    }
                    return
                }

                let total = (samples as? [HKQuantitySample])?.reduce(0.0) { partial, sample in
                    partial + sample.quantity.doubleValue(for: .count())
                } ?? 0
                continuation.resume(returning: Int(total))
            }
            store.execute(query)
        }
    }

    private struct SumResult {
        let value: Double
    }

    private func fetchSumWithAuthCheck(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> SumResult {
        SumResult(value: await fetchSum(for: identifier, unit: unit, from: start, to: end))
    }

    private func fetchSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, error in
                if let error {
                    let message = Self.authorizationErrorMessage(from: error)
                    Task { @MainActor [weak self] in
                        if let message { self?.lastReadError = message }
                        continuation.resume(returning: 0)
                    }
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private nonisolated static func authorizationErrorMessage(from error: Error) -> String? {
        guard let hkError = error as? HKError else { return nil }
        switch hkError.code {
        case .errorAuthorizationDenied, .errorAuthorizationNotDetermined:
            return hkError.localizedDescription
        default:
            return nil
        }
    }

    private func resolvedStepGoal() -> Int {
        let stored = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.dailyStepGoal)
        return stored > 0 ? stored : AppConstants.Health.defaultStepGoal
    }

    private func updateEnergyScore(activeEnergyKcal: Int) {
        switch activeEnergyKcal {
        case ..<120: latestEnergyScore = 1
        case ..<250: latestEnergyScore = 2
        case ..<400: latestEnergyScore = 3
        case ..<550: latestEnergyScore = 4
        default: latestEnergyScore = 5
        }
    }
}

extension Notification.Name {
    static let healthKitStepsDidUpdate = Notification.Name("healthKitStepsDidUpdate")
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

enum HealthKitSettingsOpener {
    static func openHealthApp() {
        if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
