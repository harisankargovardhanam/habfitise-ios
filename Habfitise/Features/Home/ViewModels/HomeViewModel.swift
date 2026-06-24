import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class HomeViewModel {
    var selectedMood = 2
    var displayName = ""
    var memberSince = Date.now
    var isGeneratingPlan = false
    private(set) var hasLoadedWorkoutSection = false

    private(set) var workoutCard = HomeWorkoutCardModel.quickStart

    var greeting: String {
        Self.makeGreeting()
    }

    var workoutTitle: String {
        workoutCard.title
    }

    var workoutChips: [String] {
        workoutCard.chips
    }
    private(set) var taskItems: [HomeTaskItem] = []
    private(set) var waterTodayML = 0
    private(set) var waterGoalML = AppConstants.Water.defaultDailyGoalML
    private(set) var streakStats = HomeStreakStats(
        weeklyCompleted: 0,
        weeklyTotal: 7,
        dayStreak: 0,
        sessionsLogged: 0,
        habitsDone: 0
    )

    private(set) var habitItems: [HomeHabitChipItem] = []

    private(set) var healthSnapshot = HomeHealthSnapshot.empty
    private(set) var healthConnectionState: HomeHealthConnectionState = .notConnected
    private var hasLoadedHealthOnce = false
    private var isHealthFetchInFlight = false
    private var lastAutomaticHealthRefresh: Date?
    private var scheduledHealthRefresh: Task<Void, Never>?

    private static let healthRefreshDebounce: Duration = .seconds(2)
    private static let healthRefreshMinimumInterval: TimeInterval = 45
    private(set) var activitySummary = DailyActivitySummary(
        health: .empty,
        workoutMinutesToday: 0,
        workoutVolumeKg: 0,
        hasCompletedWorkoutToday: false,
        combinedExerciseMinutes: 0
    )
    private(set) var dailyBrief = DailyBrief(line: "")
    private(set) var wellnessScore = WellnessScore(score: 0, workoutPoints: 0, stepsPoints: 0, habitsPoints: 0, waterPoints: 0)

    var greetingSubtitle: String {
        dailyBrief.line
    }

    static let waterGlassCount = 8

    var filledWaterDrops: Int {
        min(6, waterTodayML / AppConstants.Water.dropLogML)
    }

    var filledWaterGlasses: Int {
        guard waterGoalML > 0 else { return 0 }
        return min(Self.waterGlassCount, (waterTodayML * Self.waterGlassCount) / waterGoalML)
    }

    var waterGlassVolumeML: Int {
        guard waterGoalML > 0 else { return AppConstants.Water.cupSizeML }
        return max(waterGoalML / Self.waterGlassCount, 1)
    }

    var waterFillProgress: Double {
        guard waterGoalML > 0 else { return 0 }
        return min(Double(waterTodayML) / Double(waterGoalML), 1)
    }

    var memberSinceFormatted: String {
        memberSince.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits))
    }

    // MARK: - Bind Live Data

    func bind(
        userId: String,
        habits: [Habit],
        tasks: [TaskRecord],
        waterLogs: [WaterLog],
        workoutTemplates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        profile: UserProfile?,
        waterGoal: WaterGoal?,
        context: ModelContext
    ) {
        if let profile {
            let trimmed = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = trimmed
            memberSince = profile.createdAt
        }

        if let waterGoal {
            waterGoalML = waterGoal.dailyGoalMl
        } else {
            let stored = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
            waterGoalML = stored > 0 ? stored : AppConstants.Water.defaultDailyGoalML
        }

        waterTodayML = waterLogs.reduce(0) { $0 + $1.amountMl }
        selectedMood = resolveInitialMood(userId: userId, context: context)

        habitItems = habits.map { habit in
            HomeHabitChipItem(
                id: habit.id,
                name: habit.name,
                isCompleted: isHabitCompletedToday(habit.id, userId: userId, context: context)
            )
        }

        taskItems = tasks.prefix(3).map { task in
            HomeTaskItem(id: task.id, title: task.title, isComplete: task.isComplete)
        }

        workoutCard = buildWorkoutCard(
            templates: workoutTemplates,
            todaySessions: todaySessions,
            health: healthSnapshot
        )

        streakStats = computeStreakStats(userId: userId, habits: habits, context: context)
        hasLoadedWorkoutSection = true
    }

    /// Updates water totals and wellness context without rebuilding the rest of the dashboard.
    func syncWaterFromLogs(
        waterLogs: [WaterLog],
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord]
    ) {
        waterTodayML = waterLogs.reduce(0) { $0 + $1.amountMl }
        refreshActivityContext(
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks
        )
    }

    // MARK: - Actions

    func selectMood(_ index: Int, userId: String, context: ModelContext) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectedMood = index
        }
        MoodDao.saveCheckin(userId: userId, moodIndex: index, context: context)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func logWaterDrop(userId: String, context: ModelContext) {
        logWater(amountML: AppConstants.Water.dropLogML, userId: userId, context: context)
    }

    func logWaterGlass(userId: String, context: ModelContext) {
        logWater(amountML: waterGlassVolumeML, userId: userId, context: context)
    }

    func logWaterAmount(_ amountML: Int, userId: String, context: ModelContext) {
        logWater(amountML: amountML, userId: userId, context: context)
    }

    private func logWater(amountML: Int, userId: String, context: ModelContext) {
        let log = WaterLog(userId: userId, amountMl: amountML, source: "home_quick_add", synced: false)
        context.insert(log)
        try? context.save()

        waterTodayML += amountML
        WidgetDataPublisher.refresh(context: context, userId: userId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await NotificationService.shared.rescheduleWaterReminders(userId: userId, context: context)
        }
    }

    func generateDailyPlan(appState: AppState, userId: String, profile: UserProfile?) async {
        guard appState.isPro else {
            appState.requireUpgrade(for: .aiDailyPlan)
            return
        }

        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        let todayKey = Self.todayDateKey()
        if UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.lastDailyPlanDate) == todayKey,
           let cached = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.generatedDailyPlanJSON),
           let line = Self.summaryLine(fromPlanJSON: cached) {
            dailyBrief = DailyBrief(line: line)
            return
        }

        var goals: [String] = []
        if let goal = profile?.goal.trimmingCharacters(in: .whitespacesAndNewlines), !goal.isEmpty {
            goals.append(goal)
        }
        for habit in habitItems where !habit.isCompleted {
            goals.append(habit.name)
        }

        let preferredTime = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.preferredWorkoutTime)
        let request = DailyPlanRequest(
            date: todayKey,
            goals: goals,
            schedulePreferences: .init(
                workoutDaysPerWeek: 3,
                preferredWorkoutTime: preferredTime
            ),
            context: [
                "stepsToday": "\(healthSnapshot.steps)",
                "exerciseMinutes": "\(activitySummary.combinedExerciseMinutes)",
                "wellnessScore": "\(wellnessScore.score)",
                "openTasks": "\(taskItems.filter { !$0.isComplete }.count)"
            ]
        )

        do {
            let response = try await EdgeFunctionService.shared.generateDailyPlan(request)
            UserDefaults.standard.set(response.plan, forKey: AppConstants.UserDefaultsKeys.generatedDailyPlanJSON)
            UserDefaults.standard.set(todayKey, forKey: AppConstants.UserDefaultsKeys.lastDailyPlanDate)
            if let line = Self.summaryLine(fromPlanJSON: response.plan) {
                dailyBrief = DailyBrief(line: line)
            }
        } catch EdgeFunctionServiceError.proRequired {
            appState.requireUpgrade(for: .aiDailyPlan)
        } catch {
            // Keep ActivityEngine brief on failure.
        }
    }

    private static func todayDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private static func summaryLine(fromPlanJSON json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if let summary = object["summary"] as? String, !summary.isEmpty {
            return summary
        }
        if let suggestions = object["suggestions"] as? [[String: Any]] {
            if let text = suggestions.first?["text"] as? String, !text.isEmpty {
                return text
            }
            if let action = suggestions.first?["action"] as? String, !action.isEmpty {
                return action
            }
        }
        if let title = object["title"] as? String {
            return title
        }
        return nil
    }

    func refreshHealth(isPro: Bool, showLoading: Bool = false) async -> Bool {
        guard !isHealthFetchInFlight else { return false }
        isHealthFetchInFlight = true
        defer { isHealthFetchInFlight = false }

        guard AppConstants.Capabilities.healthKit else {
            healthConnectionState = .unavailable
            return false
        }

        await HealthKitService.shared.syncAuthorizationRequestStatus()

        guard HealthKitService.shared.isAvailable else {
            let hadData = healthSnapshot != .empty
            healthConnectionState = .unavailable
            healthSnapshot = .empty
            HealthKitService.shared.stopStepCountMonitoring()
            return hadData
        }

        guard HealthKitService.shared.hasRequestedAuthorization else {
            let hadData = healthSnapshot != .empty
            healthConnectionState = .notConnected
            healthSnapshot = .empty
            HealthKitService.shared.stopStepCountMonitoring()
            return hadData
        }

        let snapshot = await HealthKitService.shared.fetchTodaySnapshot()
        healthConnectionState = HealthKitService.shared.connectionState()
        hasLoadedHealthOnce = true
        guard snapshot != healthSnapshot else { return false }

        healthSnapshot = snapshot
        return true
    }

    func beginHealthMonitoring() {
        HealthKitService.shared.startStepCountMonitoring()
    }

    func scheduleAutomaticHealthRefresh(
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord],
        isPro: Bool,
        force: Bool = false,
        onComplete: (() -> Void)? = nil
    ) {
        if force {
            scheduledHealthRefresh?.cancel()
            scheduledHealthRefresh = Task {
                lastAutomaticHealthRefresh = Date()
                await refreshHealthData(
                    templates: templates,
                    todaySessions: todaySessions,
                    habits: habits,
                    tasks: tasks,
                    isPro: isPro,
                    showLoading: false
                )
                onComplete?()
            }
            return
        }

        scheduledHealthRefresh?.cancel()
        scheduledHealthRefresh = Task {
            try? await Task.sleep(for: Self.healthRefreshDebounce)
            guard !Task.isCancelled else { return }

            if let lastAutomaticHealthRefresh,
               Date().timeIntervalSince(lastAutomaticHealthRefresh) < Self.healthRefreshMinimumInterval {
                return
            }

            lastAutomaticHealthRefresh = Date()
            await refreshHealthData(
                templates: templates,
                todaySessions: todaySessions,
                habits: habits,
                tasks: tasks,
                isPro: isPro,
                showLoading: false
            )
            onComplete?()
        }
    }

    func refreshHealthData(
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord],
        isPro: Bool,
        showLoading: Bool = false
    ) async {
        let didChange = await refreshHealth(isPro: isPro, showLoading: showLoading)
        guard didChange else { return }
        applyHealthRefresh(
            templates: templates,
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks
        )
    }

    func updateStepGoal(
        _ goal: Int,
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord],
        isPro: Bool
    ) async {
        HealthKitService.shared.setStepGoal(goal)
        await refreshHealthData(
            templates: templates,
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks,
            isPro: isPro
        )
    }

    func applyHealthRefresh(
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord]
    ) {
        workoutCard = buildWorkoutCard(
            templates: templates,
            todaySessions: todaySessions,
            health: healthSnapshot
        )
        refreshActivityContext(
            todaySessions: todaySessions,
            habits: habits,
            tasks: tasks
        )
    }

    func refreshActivityContext(
        todaySessions: [WorkoutSession],
        habits: [Habit],
        tasks: [TaskRecord]
    ) {
        activitySummary = ActivityEngine.dailySummary(
            health: healthSnapshot,
            todaySessions: todaySessions
        )
        wellnessScore = ActivityEngine.wellnessScore(
            summary: activitySummary,
            habitsDone: habitItems.filter(\.isCompleted).count,
            habitsTotal: habits.count,
            waterProgress: waterFillProgress
        )
        dailyBrief = ActivityEngine.dailyBrief(
            summary: activitySummary,
            wellness: wellnessScore,
            habitsDone: habitItems.filter(\.isCompleted).count,
            habitsTotal: habits.count,
            openTasks: tasks.filter { !$0.isComplete }.count
        )
        WidgetDataPublisher.cacheActivity(
            stepsToday: healthSnapshot.steps,
            stepGoal: healthSnapshot.stepGoal,
            wellnessScore: wellnessScore.score
        )
    }

    func connectHealth(isPro: Bool, appState: AppState) async {
        guard isPro else {
            appState.requireUpgrade(for: .healthKitSync)
            return
        }

        do {
            try await HealthKitService.shared.requestAuthorization(isPro: true)
            await refreshHealth(isPro: isPro)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            healthConnectionState = HealthKitService.shared.connectionState()
        }
    }

    // MARK: - Private

    private func resolveInitialMood(userId: String, context: ModelContext) -> Int {
        if let healthScore = HealthKitService.shared.latestEnergyScore {
            return clampMoodIndex(healthScore - 1)
        }

        if let checkin = MoodDao.todayCheckin(userId: userId, context: context) {
            return clampMoodIndex(checkin.energyScore - 1)
        }

        return 2
    }

    private func clampMoodIndex(_ index: Int) -> Int {
        max(0, min(4, index))
    }

    private func isHabitCompletedToday(_ habitId: UUID, userId: String, context: ModelContext) -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else { return false }

        let habitIdConst = habitId
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { completion in
                completion.habitId == habitIdConst
                    && completion.completedDate >= today
                    && completion.completedDate < tomorrow
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func computeStreakStats(userId: String, habits: [Habit], context: ModelContext) -> HomeStreakStats {
        let maxStreak = habits.map { SwiftDataStack.shared.streakForHabit($0.id) }.max() ?? 0
        let userIdConst = userId
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.userId == userIdConst }
        )
        let sessionsLogged = (try? context.fetchCount(sessionDescriptor)) ?? 0
        let workoutsThisWeek = countWorkoutsThisWeek(userId: userId, context: context)
        let habitsDone = habitItems.filter(\.isCompleted).count

        return HomeStreakStats(
            weeklyCompleted: workoutsThisWeek,
            weeklyTotal: 7,
            dayStreak: maxStreak,
            sessionsLogged: sessionsLogged,
            habitsDone: habitsDone
        )
    }

    private func countWorkoutsThisWeek(userId: String, context: ModelContext) -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }

        let userIdConst = userId
        let start = weekStart
        let end = weekEnd
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userIdConst
                    && session.startedAt >= start
                    && session.startedAt < end
                    && session.completedAt != nil
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func buildWorkoutCard(
        templates: [WorkoutTemplate],
        todaySessions: [WorkoutSession],
        health: HomeHealthSnapshot
    ) -> HomeWorkoutCardModel {
        if let session = todaySessions
            .filter({ $0.completedAt != nil })
            .sorted(by: { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) })
            .first {
            return HomeWorkoutCardModel(
                mode: .completed,
                title: "Workout done! 💪",
                chips: [
                    session.name,
                    formatDuration(session.durationSeconds),
                    formatVolume(session.totalVolumeKg)
                ],
                templateId: session.templateId,
                workoutType: session.type,
                sessionId: session.id,
                summaryDuration: formatDuration(session.durationSeconds),
                summaryVolume: formatVolume(session.totalVolumeKg),
                suggestedType: nil,
                suggestionReason: nil
            )
        }

        let todayTemplates = templates
            .filter { isScheduledToday($0) }
            .sorted {
                ($0.nextScheduledAt ?? .distantFuture) < ($1.nextScheduledAt ?? .distantFuture)
            }

        if let template = todayTemplates.first {
            var chips = [
                "\(template.exercises.count) exercises",
                "\(template.estimatedMinutes) min",
                template.type.rawValue.capitalized
            ]
            if let scheduled = template.nextScheduledAt {
                chips.insert(scheduled.formatted(date: .omitted, time: .shortened), at: 0)
            }
            return HomeWorkoutCardModel(
                mode: .scheduled,
                title: template.name,
                chips: chips,
                templateId: template.id,
                workoutType: template.type,
                sessionId: nil,
                summaryDuration: nil,
                summaryVolume: nil,
                suggestedType: nil,
                suggestionReason: nil
            )
        }

        let suggestion = ActivityEngine.suggestWorkout(
            health: health,
            templates: templates,
            todaySessions: todaySessions
        )

        if let suggestion {
            return HomeWorkoutCardModel(
                mode: .quickStart,
                title: "Suggested for you",
                chips: [suggestion.reason],
                templateId: nil,
                workoutType: suggestion.type,
                sessionId: nil,
                summaryDuration: nil,
                summaryVolume: nil,
                suggestedType: suggestion.type,
                suggestionReason: suggestion.reason
            )
        }

        return .quickStart
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes) min"
    }

    private func formatVolume(_ kg: Double) -> String {
        guard kg > 0 else { return "—" }
        return "\(Int(kg)) kg volume"
    }

    private func isScheduledToday(_ template: WorkoutTemplate) -> Bool {
        guard let scheduled = template.nextScheduledAt else { return false }
        return Calendar.current.isDateInToday(scheduled)
    }

    private static func makeGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
