import Foundation
import SwiftData
import WidgetKit

enum WidgetDataPublisher {
    @MainActor
    static func refresh(context: ModelContext, userId: String) {
        let normalizedUserId = userId.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)

        let habits = fetchActiveHabits(userId: normalizedUserId, context: context)
        let habitItems = habits.map { habit in
            WidgetHabitItem(
                id: habit.id.uuidString,
                name: habit.name,
                isCompleted: isHabitCompletedToday(habit.id, context: context, today: today, tomorrow: tomorrow)
            )
        }

        let openTasks = fetchOpenTasks(userId: normalizedUserId, context: context)
        let taskItems = openTasks.map {
            WidgetTaskItem(id: $0.id.uuidString, title: $0.title, isComplete: $0.isComplete)
        }

        let waterTodayML = fetchWaterTodayML(userId: normalizedUserId, context: context, today: today, tomorrow: tomorrow)
        let waterGoalML = fetchWaterGoalML(userId: normalizedUserId, context: context)
        let glassCount = 8
        let filledWaterGlasses = waterGoalML > 0
            ? min(glassCount, (waterTodayML * glassCount) / waterGoalML)
            : 0
        let habitsDone = habitItems.filter(\.isCompleted).count
        let dayStreak = habits.map { SwiftDataStack.shared.streakForHabit($0.id) }.max() ?? 0

        let snapshot = WidgetSnapshot(
            updatedAt: .now,
            tasks: taskItems,
            habits: habitItems,
            waterTodayML: waterTodayML,
            waterGoalML: waterGoalML,
            filledWaterGlasses: filledWaterGlasses,
            waterGlassCount: glassCount,
            habitsDone: habitsDone,
            habitsTotal: habitItems.count,
            openTaskCount: taskItems.count,
            dayStreak: dayStreak
        )
        WidgetSnapshotStore.save(snapshot)
        reloadAllWidgetTimelines()
    }

    static func publishEmpty() {
        WidgetSnapshotStore.save(.empty)
        reloadAllWidgetTimelines()
    }

    private static func reloadAllWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: "VAYATasksWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "VAYAHabitsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "VAYAWaterWidget")
    }

    // MARK: - Private

    private static func fetchActiveHabits(userId: String, context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.userId == userId && $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchOpenTasks(userId: String, context: ModelContext) -> [TaskRecord] {
        let descriptor = FetchDescriptor<TaskRecord>(
            predicate: #Predicate { $0.userId == userId && $0.isComplete == false },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchWaterTodayML(
        userId: String,
        context: ModelContext,
        today: Date,
        tomorrow: Date
    ) -> Int {
        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { log in
                log.userId == userId && log.loggedAt >= today && log.loggedAt < tomorrow
            }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.reduce(0) { $0 + $1.amountMl }
    }

    private static func fetchWaterGoalML(userId: String, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let goal = try? context.fetch(descriptor).first {
            return goal.dailyGoalMl
        }
        let stored = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        return stored > 0 ? stored : AppConstants.Water.defaultDailyGoalML
    }

    private static func isHabitCompletedToday(
        _ habitId: UUID,
        context: ModelContext,
        today: Date,
        tomorrow: Date
    ) -> Bool {
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
}
