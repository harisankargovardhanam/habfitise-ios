import Foundation
import SwiftData

// MARK: - SyncTrackable

protocol SyncTrackable: PersistentModel {
    var synced: Bool { get set }
    var updatedAt: Date { get set }
}

// MARK: - UserProfile

@Model
final class UserProfile: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var displayName: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var goal: String
    var targetWeightKg: Double
    var goalDeadline: Date
    var timezone: String
    var fcmToken: String?
    var isPro: Bool
    var createdAt: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        displayName: String = "",
        age: Int = 0,
        weightKg: Double = 0,
        heightCm: Double = 0,
        goal: String = "",
        targetWeightKg: Double = 0,
        goalDeadline: Date = .now,
        timezone: String = TimeZone.current.identifier,
        fcmToken: String? = nil,
        isPro: Bool = false,
        createdAt: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.goal = goal
        self.targetWeightKg = targetWeightKg
        self.goalDeadline = goalDeadline
        self.timezone = timezone
        self.fcmToken = fcmToken
        self.isPro = isPro
        self.createdAt = createdAt
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - Habit

@Model
final class Habit: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var name: String
    var frequency: String
    var reminderTime: Date?
    var colorHex: String
    var isActive: Bool
    var createdAt: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        frequency: String = "daily",
        reminderTime: Date? = nil,
        colorHex: String = "22C55E",
        isActive: Bool = true,
        createdAt: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.frequency = frequency
        self.reminderTime = reminderTime
        self.colorHex = colorHex
        self.isActive = isActive
        self.createdAt = createdAt
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - HabitCompletion

@Model
final class HabitCompletion: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var userId: String
    var completedDate: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        habitId: UUID,
        userId: String,
        completedDate: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.habitId = habitId
        self.userId = userId
        self.completedDate = completedDate
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - Task

/// Offline-first task record. Named `TaskRecord` to avoid collision with Swift concurrency `Task`.
@Model
final class TaskRecord: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var title: String
    var dueDate: Date?
    var isComplete: Bool
    var recurrence: String?
    var linkedHabitId: UUID?
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        dueDate: Date? = nil,
        isComplete: Bool = false,
        recurrence: String? = nil,
        linkedHabitId: UUID? = nil,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.recurrence = recurrence
        self.linkedHabitId = linkedHabitId
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - MoodCheckin

@Model
final class MoodCheckin: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var energyScore: Int
    var moodScore: Int
    var note: String?
    var wearableHrv: Double?
    var wearableSleepHours: Double?
    var createdAt: Date
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        energyScore: Int,
        moodScore: Int,
        note: String? = nil,
        wearableHrv: Double? = nil,
        wearableSleepHours: Double? = nil,
        createdAt: Date = .now,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.energyScore = energyScore
        self.moodScore = moodScore
        self.note = note
        self.wearableHrv = wearableHrv
        self.wearableSleepHours = wearableSleepHours
        self.createdAt = createdAt
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - WaterLog

@Model
final class WaterLog: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var amountMl: Int
    var loggedAt: Date
    var source: String
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        amountMl: Int,
        loggedAt: Date = .now,
        source: String = "manual",
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.amountMl = amountMl
        self.loggedAt = loggedAt
        self.source = source
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - WaterGoal

@Model
final class WaterGoal: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var dailyGoalMl: Int
    var reminderIntervalMinutes: Int
    var reminderStartTime: Date
    var reminderEndTime: Date
    var isReminderEnabled: Bool
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        dailyGoalMl: Int = AppConstants.Water.defaultDailyGoalML,
        reminderIntervalMinutes: Int = 60,
        reminderStartTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now,
        reminderEndTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now,
        isReminderEnabled: Bool = true,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.dailyGoalMl = dailyGoalMl
        self.reminderIntervalMinutes = reminderIntervalMinutes
        self.reminderStartTime = reminderStartTime
        self.reminderEndTime = reminderEndTime
        self.isReminderEnabled = isReminderEnabled
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - BodyWeightEntry

@Model
final class BodyWeightEntry: SyncTrackable {
    @Attribute(.unique) var id: UUID
    var userId: String
    var loggedAt: Date
    var weightKg: Double
    var synced: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        loggedAt: Date = .now,
        weightKg: Double,
        synced: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.loggedAt = loggedAt
        self.weightKg = weightKg
        self.synced = synced
        self.updatedAt = updatedAt
    }
}

// MARK: - Schema

enum HabfitiseSwiftDataSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        WorkoutTemplate.self,
        ExerciseTemplate.self,
        WorkoutSession.self,
        ExerciseSet.self,
        MissedWorkout.self,
        PersonalRecord.self,
        BodyWeightEntry.self,
        Habit.self,
        HabitCompletion.self,
        TaskRecord.self,
        MoodCheckin.self,
        WaterLog.self,
        WaterGoal.self
    ]

    static var schema: Schema {
        Schema(modelTypes)
    }
}
