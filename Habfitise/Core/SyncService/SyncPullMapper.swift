import Foundation
import SwiftData

// MARK: - Sync scope & mode

enum SyncMode: Sendable {
    /// All rows in scope (login, onboarding).
    case full
    /// Only rows changed since last sync.
    case incremental
    /// Full pull for scope + remote wins + delete reconcile (pull-to-refresh).
    case refresh
}

enum SyncTableKind: CaseIterable, Sendable {
    case profile
    case workoutSessions
    case workoutSets
    case habits
    case habitCompletions
    case tasks
    case moodCheckins
    case waterLogs
    case waterGoals

    var tableName: String {
        switch self {
        case .profile: SyncTable.userProfiles
        case .workoutSessions: SyncTable.workoutSessions
        case .workoutSets: SyncTable.workoutSets
        case .habits: SyncTable.habits
        case .habitCompletions: SyncTable.habitCompletions
        case .tasks: SyncTable.tasks
        case .moodCheckins: SyncTable.moodCheckins
        case .waterLogs: SyncTable.waterLogs
        case .waterGoals: SyncTable.waterGoals
        }
    }
}

enum SyncScope: Sendable {
    case all
    case home
    case habits
    case tasks
    case workout
    case progress
    case profile

    var tableKinds: [SyncTableKind] {
        switch self {
        case .all:
            SyncTableKind.allCases
        case .home:
            [.profile, .tasks, .habits, .habitCompletions, .workoutSessions, .waterLogs, .waterGoals]
        case .habits:
            [.profile, .habits, .habitCompletions, .waterLogs, .waterGoals]
        case .tasks:
            [.profile, .tasks]
        case .workout:
            [.profile, .workoutSessions, .workoutSets]
        case .progress:
            [.profile, .workoutSessions, .workoutSets, .habits, .habitCompletions, .waterLogs, .moodCheckins]
        case .profile:
            [.profile]
        }
    }
}

enum SyncTimestampStore {
    static func lastSync(for userId: String) -> Date? {
        let key = AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt(for: userId)
        let timestamp = UserDefaults.standard.double(forKey: key)
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }

        let legacy = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt)
        guard legacy > 0 else { return nil }
        return Date(timeIntervalSince1970: legacy)
    }

    static func markSyncSucceeded(for userId: String, at date: Date = .now) {
        let normalized = userId.lowercased()
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt(for: normalized))
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt)
    }

    static func incrementalSince(for userId: String) -> Date? {
        guard let last = lastSync(for: userId) else { return nil }
        return last.addingTimeInterval(-AppConstants.Sync.overlapSeconds)
    }
}

/// Controls how pull-to-refresh reconciles local SwiftData with Supabase.
struct SyncPullOptions: Sendable {
    var remoteWins: Bool
    var reconcileDeletions: Bool

    init(remoteWins: Bool = false, reconcileDeletions: Bool = false) {
        self.remoteWins = remoteWins
        self.reconcileDeletions = reconcileDeletions
    }

    static let standard = SyncPullOptions()
    static let refresh = SyncPullOptions(remoteWins: true, reconcileDeletions: true)

    func shouldApply(remote: Date, local: Date) -> Bool {
        remoteWins || remote >= local
    }
}

/// Queues cloud deletes for the next sync pass (offline-safe).
@MainActor
enum SyncDeletionQueue {
    struct Entry: Codable, Equatable {
        let table: String
        let id: String
    }

    static func record(table: String, id: UUID, userId: String) {
        guard !AppConstants.Backend.useLocalOnly else { return }

        let normalizedUserId = userId.lowercased()
        let entry = Entry(table: table, id: id.uuidString.lowercased())
        var entries = load(userId: normalizedUserId)
        guard !entries.contains(entry) else { return }
        entries.append(entry)
        save(entries, userId: normalizedUserId)
    }

    static func drain(userId: String) -> [Entry] {
        let normalizedUserId = userId.lowercased()
        let entries = load(userId: normalizedUserId)
        save([], userId: normalizedUserId)
        return entries
    }

    static func peek(userId: String) -> [Entry] {
        load(userId: userId.lowercased())
    }

    static func remove(userId: String, entries: [Entry]) {
        guard !entries.isEmpty else { return }
        let normalizedUserId = userId.lowercased()
        var remaining = load(userId: normalizedUserId)
        remaining.removeAll { entries.contains($0) }
        save(remaining, userId: normalizedUserId)
    }

    static func clear(userId: String) {
        save([], userId: userId.lowercased())
    }

    private static func storageKey(userId: String) -> String {
        "pendingSyncDeletions_\(userId.lowercased())"
    }

    private static func load(userId: String) -> [Entry] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey(userId: userId)),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return []
        }
        return entries
    }

    private static func save(_ entries: [Entry], userId: String) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(userId: userId))
    }
}

/// Applies remote Supabase rows into local SwiftData (last-write-wins by `updatedAt`).
enum SyncPullMapper {
    @MainActor
    static func applyUserProfiles(
        _ rows: [UserProfileDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            if let existing = fetchUserProfile(userId: dto.userId, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
    static func applyWorkoutSessions(
        _ rows: [WorkoutSessionDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            let templateId = dto.templateId.flatMap(UUID.init(uuidString:))
            let workoutType = WorkoutType(rawValue: dto.type) ?? .weights

            if let existing = fetchWorkoutSession(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileWorkoutSessions(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyExerciseSets(
        _ rows: [ExerciseSetDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard
                let id = UUID(uuidString: dto.id),
                let sessionId = UUID(uuidString: dto.sessionId)
            else { continue }

            if let existing = fetchExerciseSet(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileExerciseSets(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyHabits(
        _ rows: [HabitDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchHabit(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileHabits(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyHabitCompletions(
        _ rows: [HabitCompletionDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard
                let id = UUID(uuidString: dto.id),
                let habitId = UUID(uuidString: dto.habitId)
            else { continue }

            if let existing = fetchHabitCompletion(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileHabitCompletions(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyTasks(
        _ rows: [TaskRecordDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            let linkedHabitId = dto.linkedHabitId.flatMap(UUID.init(uuidString:))

            if let existing = fetchTask(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileTasks(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyMoodCheckins(
        _ rows: [MoodCheckinDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchMoodCheckin(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileMoodCheckins(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyWaterLogs(
        _ rows: [WaterLogDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchWaterLog(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileWaterLogs(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyWaterGoals(
        _ rows: [WaterGoalDTO],
        userId: String,
        context: ModelContext,
        options: SyncPullOptions = .standard
    ) throws {
        for dto in rows {
            guard let id = UUID(uuidString: dto.id) else { continue }
            if let existing = fetchWaterGoal(id: id, context: context) {
                guard options.shouldApply(remote: dto.updatedAt, local: existing.updatedAt) else { continue }
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
        if options.reconcileDeletions {
            try reconcileWaterGoals(remoteRows: rows, userId: userId, context: context)
        }
        try context.save()
    }

    @MainActor
    static func applyUserDefaults(from userId: String, context: ModelContext) {
        let userIdConst = userId.lowercased()
        if let goal = try? context.fetch(FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userIdConst }
        )).first {
            UserDefaults.standard.set(goal.dailyGoalMl, forKey: AppConstants.UserDefaultsKeys.dailyWaterGoalML)
        }

        if SwiftDataStack.shared.userProfileExists(userId: userIdConst, context: context) {
            UserDefaults.standard.set(
                true,
                forKey: AppConstants.UserDefaultsKeys.onboardingCompleted(for: userIdConst)
            )
        }
    }

    // MARK: - Reconcile deletions

    private static func reconcileTasks(
        remoteRows: [TaskRecordDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<TaskRecord>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileHabits(
        remoteRows: [HabitDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<Habit>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileHabitCompletions(
        remoteRows: [HabitCompletionDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<HabitCompletion>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileWorkoutSessions(
        remoteRows: [WorkoutSessionDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileExerciseSets(
        remoteRows: [ExerciseSetDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<ExerciseSet>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileMoodCheckins(
        remoteRows: [MoodCheckinDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<MoodCheckin>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileWaterLogs(
        remoteRows: [WaterLogDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<WaterLog>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcileWaterGoals(
        remoteRows: [WaterGoalDTO],
        userId: String,
        context: ModelContext
    ) throws {
        try reconcile(
            userId: userId,
            remoteIds: Set(remoteRows.compactMap { UUID(uuidString: $0.id) }),
            context: context,
            fetchLocal: { normalized in
                try context.fetch(FetchDescriptor<WaterGoal>(
                    predicate: #Predicate { $0.userId == normalized }
                ))
            },
            recordID: \.id,
            isSynced: \.synced
        )
    }

    private static func reconcile<T: PersistentModel>(
        userId: String,
        remoteIds: Set<UUID>,
        context: ModelContext,
        fetchLocal: (String) throws -> [T],
        recordID: (T) -> UUID,
        isSynced: (T) -> Bool
    ) throws {
        let normalizedUserId = userId.lowercased()
        let local = try fetchLocal(normalizedUserId)
        for record in local where isSynced(record) && !remoteIds.contains(recordID(record)) {
            context.delete(record)
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
        let userIdConst = userId.lowercased()
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
