import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class TasksViewModel {
    var showAddTask = false
    var taskPendingDelete: TaskRecord?
    var taskPendingReschedule: TaskRecord?
    var showDeleteConfirm = false
    var showRescheduleSheet = false

    private(set) var todayTasks: [TaskRecord] = []
    private(set) var upcomingTasks: [TaskRecord] = []
    private(set) var somedayTasks: [TaskRecord] = []

    var todayCount: Int {
        todayTasks.filter { !$0.isComplete }.count
    }

    var upcomingCount: Int {
        upcomingTasks.filter { !$0.isComplete }.count
    }

    var totalOpenTasks: Int {
        todayCount + upcomingCount + somedayTasks.filter { !$0.isComplete }.count
    }

    func bind(tasks: [TaskRecord]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)

        var todayList: [TaskRecord] = []
        var upcomingList: [TaskRecord] = []
        var somedayList: [TaskRecord] = []

        for task in tasks {
            guard let dueDate = task.dueDate else {
                somedayList.append(task)
                continue
            }

            let dueDay = calendar.startOfDay(for: dueDate)
            if dueDay < tomorrow {
                todayList.append(task)
            } else {
                upcomingList.append(task)
            }
        }

        todayTasks = sortTasks(todayList)
        upcomingTasks = sortTasks(upcomingList)
        somedayTasks = sortTasks(somedayList)
    }

    func tasks(for section: TaskSection) -> [TaskRecord] {
        switch section {
        case .today: todayTasks
        case .upcoming: upcomingTasks
        case .someday: somedayTasks
        }
    }

    func completeTask(_ task: TaskRecord, context: ModelContext) {
        guard !task.isComplete else { return }

        HabfitiseHaptics.completion()

        task.isComplete = true
        task.markPendingSync()
        try? context.save()
    }

    func deleteTask(_ task: TaskRecord, context: ModelContext) {
        context.delete(task)
        try? context.save()
        taskPendingDelete = nil
        showDeleteConfirm = false
    }

    func rescheduleTask(_ task: TaskRecord, to date: Date, context: ModelContext) {
        task.dueDate = date
        task.markPendingSync()
        try? context.save()
        taskPendingReschedule = nil
        showRescheduleSheet = false
    }

    func saveTask(
        title: String,
        dueDate: Date?,
        recurrence: TaskRecurrence,
        linkedHabitId: UUID?,
        userId: String,
        context: ModelContext
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = TaskRecord(
            userId: userId,
            title: trimmed,
            dueDate: dueDate,
            recurrence: recurrence == .none ? nil : recurrence.rawValue,
            linkedHabitId: linkedHabitId,
            synced: false
        )
        context.insert(task)
        try? context.save()
    }

    func requestDelete(_ task: TaskRecord) {
        taskPendingDelete = task
        showDeleteConfirm = true
    }

    func requestReschedule(_ task: TaskRecord) {
        taskPendingReschedule = task
        showRescheduleSheet = true
    }

    // MARK: - Private

    private func sortTasks(_ tasks: [TaskRecord]) -> [TaskRecord] {
        tasks.sorted { lhs, rhs in
            if lhs.isComplete != rhs.isComplete {
                return !lhs.isComplete && rhs.isComplete
            }

            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                return left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
