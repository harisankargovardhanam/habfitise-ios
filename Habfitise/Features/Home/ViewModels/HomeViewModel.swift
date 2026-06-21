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
        Self.makeGreeting(name: displayName)
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

        workoutCard = buildWorkoutCard(
            templates: workoutTemplates,
            todaySessions: todaySessions
        )

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

        streakStats = computeStreakStats(userId: userId, habits: habits, context: context)
        hasLoadedWorkoutSection = true
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

    private func logWater(amountML: Int, userId: String, context: ModelContext) {
        let log = WaterLog(userId: userId, amountMl: amountML, source: "home_glass", synced: false)
        context.insert(log)
        try? context.save()

        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
            waterTodayML += amountML
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func generateDailyPlan(appState: AppState) async {
        guard appState.isPro else {
            appState.requireUpgrade(for: .aiDailyPlan)
            return
        }
        isGeneratingPlan = true
        isGeneratingPlan = false
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var completedDays = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { continue }

            let dayStart = day
            let dayEnd = next
            let descriptor = FetchDescriptor<HabitCompletion>(
                predicate: #Predicate { $0.completedDate >= dayStart && $0.completedDate < dayEnd }
            )
            if ((try? context.fetchCount(descriptor)) ?? 0) > 0 {
                completedDays += 1
            }
        }

        let maxStreak = habits.map { SwiftDataStack.shared.streakForHabit($0.id) }.max() ?? 0
        let userIdConst = userId
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.userId == userIdConst }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let workoutsThisWeek = countWorkoutsThisWeek(userId: userId, context: context)
        let habitsDone = habitItems.filter(\.isCompleted).count

        return HomeStreakStats(
            weeklyCompleted: workoutsThisWeek,
            weeklyTotal: 7,
            dayStreak: maxStreak,
            sessionsLogged: sessions.count,
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
        todaySessions: [WorkoutSession]
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
                summaryVolume: formatVolume(session.totalVolumeKg)
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
                summaryVolume: nil
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

    private static func makeGreeting(name: String) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return timeGreeting }
        return "\(timeGreeting), \(trimmed)"
    }
}
