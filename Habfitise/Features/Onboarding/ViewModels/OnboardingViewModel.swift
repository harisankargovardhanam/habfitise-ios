import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    // MARK: - Navigation

    var step = 0
    let totalSteps = 4

    // MARK: - Step 2 — Goal

    var selectedGoal: OnboardingGoalOption?

    // MARK: - Step 3 — Weight & Timeline

    var currentWeightKg: Double = 75
    var targetWeightKg: Double = 68
    var weightUnit: WeightUnit = .kg
    var timeline: GoalTimeline = .sixMonths

    // MARK: - Step 4 — Schedule

    var selectedWeekdays: Set<Int> = [0, 2, 4]
    var preferredTime: PreferredTrainingTime = .morning
    var equipment: TrainingEquipment = .gym
    var dailyWaterGoalML: Int = AppConstants.Water.defaultDailyGoalML

    // MARK: - Build Plan State

    var isBuildingPlan = false
    var cardContentVisible = true
    var loadingMessageIndex = 0
    var buildError: String?

    let loadingMessages = [
        "Analysing your goal...",
        "Scheduling your week...",
        "Almost ready..."
    ]

    private var loadingTask: Task<Void, Never>?

    // MARK: - Validation

    var canContinue: Bool {
        switch step {
        case 0: true
        case 1: selectedGoal != nil
        case 2: currentWeightKg > 0 && targetWeightKg > 0
        case 3: !selectedWeekdays.isEmpty && dailyWaterGoalML >= 500
        default: false
        }
    }

    // MARK: - Goal Summary

    var goalSummary: OnboardingGoalSummary {
        let unit = weightUnit.label
        let current = weightUnit.display(currentWeightKg)
        let target = weightUnit.display(targetWeightKg)
        let delta = abs(target - current)
        let formattedDelta = String(format: "%.1f", delta)
        let months = timeline.monthCount
        let monthly = delta / Double(months)
        let formattedMonthly = String(format: "%.1f", monthly)

        let headline: String
        switch selectedGoal {
        case .loseWeight:
            headline = "Lose \(formattedDelta) \(unit) in \(timeline.label)"
        case .buildMuscle:
            headline = "Gain \(formattedDelta) \(unit) in \(timeline.label)"
        case .improveFitness:
            headline = "Reach \(String(format: "%.0f", target)) \(unit) in \(timeline.label)"
        case .buildHabits:
            headline = "Build healthy habits in \(timeline.label)"
        case nil:
            headline = "Set your goal in the previous step"
        }

        let monthlyRate = "~\(formattedMonthly) \(unit) per month"
        return OnboardingGoalSummary(headline: headline, monthlyRate: monthlyRate)
    }

    // MARK: - Navigation

    func nextStep() {
        guard step < totalSteps - 1 else { return }
        step += 1
    }

    func previousStep() {
        guard step > 0 else { return }
        step -= 1
    }

    // MARK: - Weight Helpers

    func incrementCurrentWeight() {
        adjustCurrentWeight(by: 1)
    }

    func decrementCurrentWeight() {
        adjustCurrentWeight(by: -1)
    }

    func incrementTargetWeight() {
        adjustTargetWeight(by: 1)
    }

    func decrementTargetWeight() {
        adjustTargetWeight(by: -1)
    }

    var displayCurrentWeight: Double {
        weightUnit.display(currentWeightKg)
    }

    var displayTargetWeight: Double {
        weightUnit.display(targetWeightKg)
    }

    func adjustWaterGoal(by delta: Int) {
        dailyWaterGoalML = min(max(dailyWaterGoalML + delta, 500), 5000)
    }

    func toggleWeekday(_ index: Int) {
        if selectedWeekdays.contains(index) {
            selectedWeekdays.remove(index)
        } else {
            selectedWeekdays.insert(index)
        }
    }

    // MARK: - Build Plan

    func buildMyPlan(appState: AppState, syncService: SyncService, context: ModelContext) async {
        guard let userId = appState.authenticatedUserId else { return }
        guard !isBuildingPlan else { return }

        buildError = nil
        isBuildingPlan = true

        withAnimation(.easeOut(duration: 0.3)) {
            cardContentVisible = false
        }

        try? await Task.sleep(for: .milliseconds(300))
        startLoadingMessageCycle()

        do {
            let request = makeWorkoutPlanRequest(userId: userId)
            let response = try await EdgeFunctionService.shared.generateWorkoutPlan(request)

            try saveOnboardingData(
                userId: userId,
                response: response,
                context: context
            )

            await syncService.syncAll(modelContext: context, userId: userId)
            appState.finishOnboarding()
        } catch {
            buildError = error.localizedDescription
            withAnimation(.easeOut(duration: 0.3)) {
                cardContentVisible = true
            }
        }

        stopLoadingMessageCycle()
        isBuildingPlan = false
    }

    func signOutExistingAccount(appState: AppState) async {
        if AppConstants.Backend.useLocalOnly {
            LocalSessionService.clearSession()
        } else {
            try? await SupabaseManager.shared.signOut()
        }
        appState.signOut()
    }

    // MARK: - Private

    private func adjustCurrentWeight(by step: Double) {
        let display = weightUnit.display(currentWeightKg) + step
        currentWeightKg = max(weightUnit.toKilograms(display), 1)
    }

    private func adjustTargetWeight(by step: Double) {
        let display = weightUnit.display(targetWeightKg) + step
        targetWeightKg = max(weightUnit.toKilograms(display), 1)
    }

    private func makeWorkoutPlanRequest(userId: String) -> WorkoutPlanRequest {
        let trainingDays = Weekday.allCases
            .filter { selectedWeekdays.contains($0.rawValue) }
            .map(\.apiKey)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return WorkoutPlanRequest(
            userId: userId,
            goal: selectedGoal?.rawValue ?? "",
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            goalDeadline: formatter.string(from: timeline.deadline),
            timelineMonths: timeline.monthCount,
            trainingDays: trainingDays,
            preferredTime: preferredTime.rawValue,
            equipment: equipment.rawValue,
            dailyWaterGoalMl: dailyWaterGoalML
        )
    }

    private func saveOnboardingData(
        userId: String,
        response: WorkoutPlanResponse,
        context: ModelContext
    ) throws {
        let profile = UserProfile(
            userId: userId,
            displayName: "",
            weightKg: currentWeightKg,
            goal: selectedGoal?.rawValue ?? "",
            targetWeightKg: targetWeightKg,
            goalDeadline: timeline.deadline,
            synced: false
        )
        context.insert(profile)

        UserDefaults.standard.set(response.plan, forKey: AppConstants.UserDefaultsKeys.generatedWorkoutPlanJSON)

        let parsed = HomeWorkoutPlanParser.parse(planJSON: response.plan)
        let template = WorkoutTemplate(
            userId: userId,
            name: parsed.name,
            type: .weights,
            estimatedMinutes: parsed.durationMinutes,
            notes: "Generated from onboarding plan",
            synced: false
        )
        context.insert(template)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if let firstDate = nextDate(forWeekday: selectedWeekdays.sorted().first ?? 0, from: today, calendar: calendar) {
            template.nextScheduledAt = firstDate
        }

        let waterGoal = WaterGoal(
            userId: userId,
            dailyGoalMl: dailyWaterGoalML,
            synced: false
        )
        context.insert(waterGoal)

        UserDefaults.standard.set(dailyWaterGoalML, forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        UserDefaults.standard.set(preferredTime.rawValue, forKey: AppConstants.UserDefaultsKeys.preferredWorkoutTime)
        try context.save()
    }

    private func nextDate(forWeekday weekday: Int, from start: Date, calendar: Calendar) -> Date? {
        for offset in 0..<14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let index = (calendar.component(.weekday, from: candidate) + 5) % 7
            if index == weekday {
                return candidate
            }
        }
        return nil
    }

    private func startLoadingMessageCycle() {
        loadingMessageIndex = 0
        loadingTask?.cancel()
        loadingTask = Task {
            while !Task.isCancelled, isBuildingPlan {
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { break }
                loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
            }
        }
    }

    private func stopLoadingMessageCycle() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}
