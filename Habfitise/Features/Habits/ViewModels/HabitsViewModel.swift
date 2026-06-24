import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class HabitsViewModel {
    var showAddHabit = false
    var habitPendingDelete: Habit?
    var showDeleteConfirm = false
    var waterCelebrationActive = false
    var animatingCupIndex: Int?

    private(set) var waterTodayML = 0
    private(set) var waterGoalML = AppConstants.Water.defaultDailyGoalML
    private(set) var nextReminderMinutes = AppConstants.Water.defaultReminderIntervalMinutes
    private(set) var hasLoadedHabits = false

    static let waterCupVolumeML = 350
    static let waterCupCount = 8
    static let homeWaterCupCount = 6

    func filledWaterCups(for cupCount: Int) -> Int {
        min(cupCount, waterTodayML / Self.waterCupVolumeML)
    }

    var filledWaterCups: Int {
        filledWaterCups(for: Self.waterCupCount)
    }

    var allWaterCupsFilled: Bool {
        waterGoalML > 0 && waterTodayML >= waterGoalML
    }

    var waterProgress: Double {
        guard waterGoalML > 0 else { return 0 }
        return min(Double(waterTodayML) / Double(waterGoalML), 1)
    }

    // MARK: - Bind

    func bind(
        habits: [Habit],
        completions: [HabitCompletion],
        waterLogs: [WaterLog],
        waterGoal: WaterGoal?
    ) {
        waterTodayML = waterLogs.reduce(0) { $0 + $1.amountMl }

        if let waterGoal {
            waterGoalML = waterGoal.dailyGoalMl
            nextReminderMinutes = waterGoal.reminderIntervalMinutes
        } else {
            waterGoalML = AppConstants.Water.defaultDailyGoalML
            nextReminderMinutes = AppConstants.Water.defaultReminderIntervalMinutes
        }

        _ = habits
        _ = completions
        hasLoadedHabits = true
    }

    /// Convenience for lightweight @Query examples.
    func bind(habits: [Habit]) {
        bind(habits: habits, completions: [], waterLogs: [], waterGoal: nil)
    }

    func activeHabitCount(from habits: [Habit]) -> Int {
        habits.filter(\.isActive).count
    }

    func aggregateStreak(from habits: [Habit]) -> Int {
        guard !habits.isEmpty else { return 0 }
        return habits.map { streak(for: $0.id) }.max() ?? 0
    }

    // MARK: - Streak & Completions

    func streak(for habitId: UUID) -> Int {
        SwiftDataStack.shared.streakForHabit(habitId)
    }

    func isCompletedToday(habitId: UUID, completions: [HabitCompletion]) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return false }

        return completions.contains { completion in
            completion.habitId == habitId
                && completion.completedDate >= today
                && completion.completedDate < tomorrow
        }
    }

    func weekDays(for habitId: UUID, completions: [HabitCompletion]) -> [HabitDayItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = Self.mondayStart(for: today, calendar: calendar)

        let labels = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? today
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let completed = completions.contains { completion in
                completion.habitId == habitId
                    && completion.completedDate >= dayStart
                    && completion.completedDate < dayEnd
            }

            return HabitDayItem(
                date: dayStart,
                weekdayLabel: labels[offset],
                isCompleted: completed,
                isToday: calendar.isDate(dayStart, inSameDayAs: today),
                isFuture: dayStart > today
            )
        }
    }

    private static func mondayStart(for date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date)) ?? date
    }

    // MARK: - Actions

    func completeHabit(
        _ habit: Habit,
        userId: String,
        completions: [HabitCompletion],
        context: ModelContext,
        syncService: SyncService
    ) -> Int? {
        guard !isCompletedToday(habitId: habit.id, completions: completions) else { return nil }

        HabfitiseHaptics.completion()

        let normalizedUserId = userId.lowercased()
        let completion = HabitCompletion(
            habitId: habit.id,
            userId: normalizedUserId,
            completedDate: .now,
            synced: false
        )
        completion.markPendingSync()
        context.insert(completion)
        try? context.save()

        syncService.schedulePush(modelContext: context, userId: normalizedUserId)
        WidgetDataPublisher.refresh(context: context, userId: normalizedUserId)

        Task {
            await NotificationService.shared.scheduleHabitReminder(habit: habit, context: context)
        }

        let newStreak = streak(for: habit.id)
        if HabitStreakMilestone.isMilestone(newStreak) {
            return newStreak
        }
        return nil
    }

    func undoHabitToday(
        _ habit: Habit,
        completions: [HabitCompletion],
        context: ModelContext,
        syncService: SyncService
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        let todaysCompletions = completions.filter { completion in
            completion.habitId == habit.id
                && completion.completedDate >= today
                && completion.completedDate < tomorrow
        }

        guard !todaysCompletions.isEmpty else { return }

        for completion in todaysCompletions {
            if completion.synced {
                SyncDeletionQueue.record(
                    table: SyncTable.habitCompletions,
                    id: completion.id,
                    userId: completion.userId
                )
            }
            context.delete(completion)
        }
        try? context.save()
        syncService.schedulePush(modelContext: context, userId: habit.userId.lowercased())
        WidgetDataPublisher.refresh(context: context, userId: habit.userId)

        Task {
            await NotificationService.shared.scheduleHabitReminder(habit: habit, context: context)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func addWaterLog(
        amountMl: Int,
        userId: String,
        context: ModelContext,
        syncService: SyncService
    ) {
        let normalizedUserId = userId.lowercased()
        let log = WaterLog(
            userId: normalizedUserId,
            amountMl: amountMl,
            source: "habits_cup",
            synced: false
        )
        log.markPendingSync()
        context.insert(log)
        try? context.save()

        syncService.schedulePush(modelContext: context, userId: normalizedUserId)
        WidgetDataPublisher.refresh(context: context, userId: normalizedUserId)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            waterTodayML += amountMl
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await NotificationService.shared.rescheduleWaterReminders(userId: userId, context: context)
        }
    }

    func addWater(
        at cupIndex: Int,
        userId: String,
        context: ModelContext,
        syncService: SyncService,
        cupCount: Int = waterCupCount
    ) {
        guard cupIndex == filledWaterCups(for: cupCount), cupIndex < cupCount else { return }

        animatingCupIndex = cupIndex
        addWaterLog(amountMl: Self.waterCupVolumeML, userId: userId, context: context, syncService: syncService)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.animatingCupIndex = nil
        }
    }

    func shouldCelebrateWaterFill() -> Bool {
        filledWaterCups >= Self.waterCupCount || waterTodayML >= waterGoalML
    }

    func beginWaterCelebration() {
        guard !waterCelebrationActive else { return }
        waterCelebrationActive = true
    }

    func endWaterCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            waterCelebrationActive = false
        }
    }

    func requestDelete(_ habit: Habit) {
        habitPendingDelete = habit
        showDeleteConfirm = true
    }

    func deleteHabit(_ habit: Habit, context: ModelContext, syncService: SyncService) {
        let habitIdConst = habit.id
        let completionDescriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { $0.habitId == habitIdConst }
        )
        let completions = (try? context.fetch(completionDescriptor)) ?? []
        for completion in completions {
            if completion.synced {
                SyncDeletionQueue.record(
                    table: SyncTable.habitCompletions,
                    id: completion.id,
                    userId: completion.userId
                )
            }
            context.delete(completion)
        }

        if habit.synced {
            SyncDeletionQueue.record(table: SyncTable.habits, id: habit.id, userId: habit.userId)
        }

        context.delete(habit)
        try? context.save()

        syncService.schedulePush(modelContext: context, userId: habit.userId.lowercased())
        WidgetDataPublisher.refresh(context: context, userId: habit.userId)

        Task {
            await NotificationService.shared.cancelHabitReminder(habitId: habitIdConst)
        }

        habitPendingDelete = nil
        showDeleteConfirm = false
    }

    func saveHabit(
        name: String,
        frequency: String,
        reminderTime: Date?,
        colorHex: String,
        userId: String,
        context: ModelContext
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let habit = Habit(
            userId: userId,
            name: trimmed,
            frequency: frequency,
            reminderTime: reminderTime,
            colorHex: colorHex,
            synced: false
        )
        context.insert(habit)
        try? context.save()
        WidgetDataPublisher.refresh(context: context, userId: userId)
        Task {
            await NotificationService.shared.scheduleHabitReminder(habit: habit, context: context)
        }
    }
}
