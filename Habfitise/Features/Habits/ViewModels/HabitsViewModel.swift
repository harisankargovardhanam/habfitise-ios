import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class HabitsViewModel {
    var showAddHabit = false
    var waterCelebrationActive = false
    var animatingCupIndex: Int?

    private(set) var waterTodayML = 0
    private(set) var waterGoalML = AppConstants.Water.defaultDailyGoalML
    private(set) var nextReminderMinutes = 45
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
            nextReminderMinutes = max(waterGoal.reminderIntervalMinutes / 2, 15)
        } else {
            waterGoalML = AppConstants.Water.defaultDailyGoalML
            nextReminderMinutes = 45
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
        context: ModelContext
    ) -> Int? {
        guard !isCompletedToday(habitId: habit.id, completions: completions) else { return nil }

        HabfitiseHaptics.completion()

        let completion = HabitCompletion(
            habitId: habit.id,
            userId: userId,
            completedDate: .now,
            synced: false
        )
        context.insert(completion)
        try? context.save()

        let newStreak = streak(for: habit.id)
        if HabitStreakMilestone.isMilestone(newStreak) {
            return newStreak
        }
        return nil
    }

    func addWaterLog(amountMl: Int, userId: String, context: ModelContext) {
        let log = WaterLog(
            userId: userId,
            amountMl: amountMl,
            source: "habits_cup",
            synced: false
        )
        context.insert(log)
        try? context.save()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            waterTodayML += amountMl
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func addWater(at cupIndex: Int, userId: String, context: ModelContext, cupCount: Int = waterCupCount) {
        guard cupIndex == filledWaterCups(for: cupCount), cupIndex < cupCount else { return }

        animatingCupIndex = cupIndex
        addWaterLog(amountMl: Self.waterCupVolumeML, userId: userId, context: context)

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
    }
}
