import Foundation
import SwiftData

/// Applies remote Supabase rows into local SwiftData (last-write-wins by `updatedAt`).
enum SyncPullMapper {
    @MainActor
    static func applyUserProfiles(_ rows: [UserProfileDTO], context: ModelContext) throws {
        for dto in rows {
            if let existing = fetchUserProfile(userId: dto.userId, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                copyUserProfile(dto, into: existing)
                existing.synced = true
            } else {
                let profile = UserProfile(
                    userId: dto.userId,
                    displayName: dto.displayName,
                    age: dto.age,
                    weightKg: dto.weightKg,
                    heightCm: dto.heightCm,
                    goal: dto.goal,
                    targetWeightKg: dto.targetWeightKg,
                    goalDeadline: dto.goalDeadline,
                    timezone: dto.timezone,
                    fcmToken: dto.fcmToken,
                    isPro: dto.isPro,
                    createdAt: dto.createdAt,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(profile)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyWorkoutSessions(_ rows: [WorkoutSessionDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            let templateId = dto.templateId.flatMap(UUID.init(uuidString:))
            let workoutType = WorkoutType(rawValue: dto.type) ?? .weights

            if let existing = fetchWorkoutSession(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.templateId = templateId
                existing.name = dto.name
                existing.type = workoutType
                existing.startedAt = dto.startedAt
                existing.completedAt = dto.completedAt
                existing.durationSeconds = dto.durationSeconds
                existing.totalVolumeKg = dto.totalVolumeKg
                existing.totalCalories = dto.totalCalories
                existing.notes = dto.notes
                existing.mood = dto.mood
                existing.perceivedExertion = dto.perceivedExertion
                existing.remoteId = dto.remoteId
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let session = WorkoutSession(
                    id: id,
                    userId: dto.userId,
                    templateId: templateId,
                    name: dto.name,
                    type: workoutType,
                    startedAt: dto.startedAt,
                    completedAt: dto.completedAt,
                    durationSeconds: dto.durationSeconds,
                    totalVolumeKg: dto.totalVolumeKg,
                    totalCalories: dto.totalCalories,
                    notes: dto.notes,
                    mood: dto.mood,
                    perceivedExertion: dto.perceivedExertion,
                    synced: true,
                    remoteId: dto.remoteId,
                    updatedAt: dto.updatedAt
                )
                context.insert(session)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyExerciseSets(_ rows: [ExerciseSetDTO], context: ModelContext) throws {
        for dto in rows {
            guard
                let id = UUID(uuidString: dto.id),
                let sessionId = UUID(uuidString: dto.sessionId)
            else { continue }

            if let existing = fetchExerciseSet(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.sessionId = sessionId
                existing.userId = dto.userId
                existing.exerciseName = dto.exerciseName
                existing.exerciseCategory = dto.exerciseCategory
                existing.setNumber = dto.setNumber
                existing.reps = dto.reps
                existing.weightKg = dto.weightKg
                existing.durationSeconds = dto.durationSeconds
                existing.distanceKm = dto.distanceKm
                existing.isWarmup = dto.isWarmup
                existing.isPersonalRecord = dto.isPersonalRecord
                existing.completedAt = dto.completedAt
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let set = ExerciseSet(
                    id: id,
                    sessionId: sessionId,
                    userId: dto.userId,
                    exerciseName: dto.exerciseName,
                    exerciseCategory: dto.exerciseCategory,
                    setNumber: dto.setNumber,
                    reps: dto.reps,
                    weightKg: dto.weightKg,
                    durationSeconds: dto.durationSeconds,
                    distanceKm: dto.distanceKm,
                    isWarmup: dto.isWarmup,
                    isPersonalRecord: dto.isPersonalRecord,
                    completedAt: dto.completedAt,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(set)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyHabits(_ rows: [HabitDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchHabit(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.name = dto.name
                existing.frequency = dto.frequency
                existing.reminderTime = dto.reminderTime
                existing.colorHex = dto.colorHex
                existing.isActive = dto.isActive
                existing.createdAt = dto.createdAt
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let habit = Habit(
                    id: id,
                    userId: dto.userId,
                    name: dto.name,
                    frequency: dto.frequency,
                    reminderTime: dto.reminderTime,
                    colorHex: dto.colorHex,
                    isActive: dto.isActive,
                    createdAt: dto.createdAt,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(habit)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyHabitCompletions(_ rows: [HabitCompletionDTO], context: ModelContext) throws {
        for dto in rows {
            guard
                let id = UUID(uuidString: dto.id),
                let habitId = UUID(uuidString: dto.habitId)
            else { continue }

            if let existing = fetchHabitCompletion(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.habitId = habitId
                existing.userId = dto.userId
                existing.completedDate = dto.completedDate
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let completion = HabitCompletion(
                    id: id,
                    habitId: habitId,
                    userId: dto.userId,
                    completedDate: dto.completedDate,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(completion)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyTasks(_ rows: [TaskRecordDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            let linkedHabitId = dto.linkedHabitId.flatMap(UUID.init(uuidString:))

            if let existing = fetchTask(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.title = dto.title
                existing.dueDate = dto.dueDate
                existing.isComplete = dto.isComplete
                existing.recurrence = dto.recurrence
                existing.linkedHabitId = linkedHabitId
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let task = TaskRecord(
                    id: id,
                    userId: dto.userId,
                    title: dto.title,
                    dueDate: dto.dueDate,
                    isComplete: dto.isComplete,
                    recurrence: dto.recurrence,
                    linkedHabitId: linkedHabitId,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(task)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyMoodCheckins(_ rows: [MoodCheckinDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchMoodCheckin(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.energyScore = dto.energyScore
                existing.moodScore = dto.moodScore
                existing.note = dto.note
                existing.wearableHrv = dto.wearableHrvDouble
                existing.wearableSleepHours = dto.wearableSleepHours
                existing.createdAt = dto.createdAt
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let checkin = MoodCheckin(
                    id: id,
                    userId: dto.userId,
                    energyScore: dto.energyScore,
                    moodScore: dto.moodScore,
                    note: dto.note,
                    wearableHrv: dto.wearableHrvDouble,
                    wearableSleepHours: dto.wearableSleepHours,
                    createdAt: dto.createdAt,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(checkin)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyWaterLogs(_ rows: [WaterLogDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchWaterLog(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.amountMl = dto.amountMl
                existing.loggedAt = dto.loggedAt
                existing.source = dto.source
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let log = WaterLog(
                    id: id,
                    userId: dto.userId,
                    amountMl: dto.amountMl,
                    loggedAt: dto.loggedAt,
                    source: dto.source,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(log)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyWaterGoals(_ rows: [WaterGoalDTO], context: ModelContext) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchWaterGoal(id: id, context: context) {
                guard dto.updatedAt >= existing.updatedAt else { continue }
                existing.userId = dto.userId
                existing.dailyGoalMl = dto.dailyGoalMl
                existing.reminderIntervalMinutes = dto.reminderIntervalMinutes
                existing.reminderStartTime = dto.reminderStartTime
                existing.reminderEndTime = dto.reminderEndTime
                existing.isReminderEnabled = dto.isReminderEnabled
                existing.updatedAt = dto.updatedAt
                existing.synced = true
            } else {
                let goal = WaterGoal(
                    id: id,
                    userId: dto.userId,
                    dailyGoalMl: dto.dailyGoalMl,
                    reminderIntervalMinutes: dto.reminderIntervalMinutes,
                    reminderStartTime: dto.reminderStartTime,
                    reminderEndTime: dto.reminderEndTime,
                    isReminderEnabled: dto.isReminderEnabled,
                    synced: true,
                    updatedAt: dto.updatedAt
                )
                context.insert(goal)
            }
        }
        try context.save()
    }

    @MainActor
    static func applyUserDefaults(from userId: String, context: ModelContext) {
        let userIdConst = userId
        if let goal = try? context.fetch(FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userIdConst }
        )).first {
            UserDefaults.standard.set(goal.dailyGoalMl, forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        }

        if SwiftDataStack.shared.userProfileExists(userId: userId, context: context) {
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: userId)
            )
        }
    }

    // MARK: - Private

    private static func copyUserProfile(_ dto: UserProfileDTO, into profile: UserProfile) {
        profile.displayName = dto.displayName
        profile.age = dto.age
        profile.weightKg = dto.weightKg
        profile.heightCm = dto.heightCm
        profile.goal = dto.goal
        profile.targetWeightKg = dto.targetWeightKg
        profile.goalDeadline = dto.goalDeadline
        profile.timezone = dto.timezone
        profile.fcmToken = dto.fcmToken
        profile.isPro = dto.isPro
        profile.createdAt = dto.createdAt
        profile.updatedAt = dto.updatedAt
    }

    private static func fetchUserProfile(userId: String, context: ModelContext) -> UserProfile? {
        let userIdConst = userId
        return try? context.fetch(FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userIdConst }
        )).first
    }

    private static func fetchUserProfile(id: UUID, context: ModelContext) -> UserProfile? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchWorkoutSession(id: UUID, context: ModelContext) -> WorkoutSession? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchExerciseSet(id: UUID, context: ModelContext) -> ExerciseSet? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchHabit(id: UUID, context: ModelContext) -> Habit? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchHabitCompletion(id: UUID, context: ModelContext) -> HabitCompletion? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchTask(id: UUID, context: ModelContext) -> TaskRecord? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<TaskRecord>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchMoodCheckin(id: UUID, context: ModelContext) -> MoodCheckin? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<MoodCheckin>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchWaterLog(id: UUID, context: ModelContext) -> WaterLog? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }

    private static func fetchWaterGoal(id: UUID, context: ModelContext) -> WaterGoal? {
        let idConst = id
        return try? context.fetch(FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.id == idConst }
        )).first
    }
}
