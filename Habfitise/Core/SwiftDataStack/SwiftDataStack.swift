import Foundation
import SwiftData

@MainActor
final class SwiftDataStack {
    static let shared = SwiftDataStack()

    let container: ModelContainer

    var mainContext: ModelContext {
        container.mainContext
    }

    private init(inMemory: Bool = false) {
        do {
            container = try Self.makeContainer(inMemory: inMemory)
        } catch {
            fatalError("SwiftDataStack failed to initialize: \(error)")
        }
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(
                schema: HabfitiseSwiftDataSchema.schema,
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(
                for: HabfitiseSwiftDataSchema.schema,
                configurations: [configuration]
            )
        } 

        let storeURL = persistentStoreURL()
        do {
            return try openContainer(at: storeURL)
        } catch {
            // Breaking schema changes (e.g. workout model rewrite) invalidate the old store.
            removeStoreFiles(at: storeURL)
            return try openContainer(at: storeURL)
        }
    }

    private static func openContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: HabfitiseSwiftDataSchema.schema,
            url: storeURL
        )
        return try ModelContainer(
            for: HabfitiseSwiftDataSchema.schema,
            configurations: [configuration]
        )
    }

    private static func persistentStoreURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(AppConstants.SwiftData.storeFileName)
    }

    private static func removeStoreFiles(at url: URL) {
        let paths = [url.path, url.path + "-wal", url.path + "-shm"]
        for path in paths where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    static func makePreviewStack() -> SwiftDataStack {
        SwiftDataStack(inMemory: true)
    }

    // MARK: - Workouts

    func fetchTemplates(userId: String, type: WorkoutType? = nil) -> [WorkoutTemplate] {
        if let type {
            let workoutType = type
            let descriptor = FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { template in
                    template.userId == userId && template.type == workoutType
                },
                sortBy: [SortDescriptor(\.lastPerformedAt, order: .reverse)]
            )
            return (try? mainContext.fetch(descriptor)) ?? []
        }

        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.lastPerformedAt, order: .reverse)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func fetchRecentSessions(userId: String, limit: Int = 10) -> [WorkoutSession] {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userId && session.completedAt != nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func fetchSessionsThisWeek(userId: String) -> [WorkoutSession] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userId
                    && session.startedAt >= weekStart
                    && session.startedAt < weekEnd
                    && session.completedAt != nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func fetchPR(userId: String, exerciseName: String, type: PRType) -> PersonalRecord? {
        let name = exerciseName
        let recordType = type
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { record in
                record.userId == userId
                    && record.exerciseName == name
                    && record.recordType == recordType
            },
            sortBy: [SortDescriptor(\.value, order: .reverse)]
        )
        return try? mainContext.fetch(descriptor).first
    }

    func fetchMissedWorkouts(userId: String, status: MissedWorkoutAction) -> [MissedWorkout] {
        let descriptor = FetchDescriptor<MissedWorkout>(
            predicate: #Predicate { missed in
                missed.userId == userId
            },
            sortBy: [SortDescriptor(\.scheduledDate, order: .reverse)]
        )
        return ((try? mainContext.fetch(descriptor)) ?? []).filter { $0.action == status }
    }

    func checkForNewPR(set: ExerciseSet, userId: String) -> PersonalRecord? {
        let exerciseName = set.exerciseName
        let sessionId = set.sessionId

        if let weight = set.weightKg, let reps = set.reps, reps > 0 {
            let volume = weight * Double(reps)

            if let existing = fetchPR(userId: userId, exerciseName: exerciseName, type: .maxWeight),
               weight > existing.value {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .maxWeight,
                    value: weight,
                    unit: "kg",
                    sessionId: sessionId
                )
            } else if fetchPR(userId: userId, exerciseName: exerciseName, type: .maxWeight) == nil {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .maxWeight,
                    value: weight,
                    unit: "kg",
                    sessionId: sessionId
                )
            }

            if let existing = fetchPR(userId: userId, exerciseName: exerciseName, type: .maxVolume),
               volume > existing.value {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .maxVolume,
                    value: volume,
                    unit: "kg·reps",
                    sessionId: sessionId
                )
            } else if fetchPR(userId: userId, exerciseName: exerciseName, type: .maxVolume) == nil, volume > 0 {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .maxVolume,
                    value: volume,
                    unit: "kg·reps",
                    sessionId: sessionId
                )
            }
        }

        if let distance = set.distanceKm, distance > 0 {
            if let existing = fetchPR(userId: userId, exerciseName: exerciseName, type: .longestDistance),
               distance > existing.value {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .longestDistance,
                    value: distance,
                    unit: "km",
                    sessionId: sessionId
                )
            } else if fetchPR(userId: userId, exerciseName: exerciseName, type: .longestDistance) == nil {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .longestDistance,
                    value: distance,
                    unit: "km",
                    sessionId: sessionId
                )
            }
        }

        if let duration = set.durationSeconds, duration > 0,
           let distance = set.distanceKm, distance > 0 {
            let pace = Double(duration) / 60.0 / distance
            if let existing = fetchPR(userId: userId, exerciseName: exerciseName, type: .fastestPace),
               pace < existing.value {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .fastestPace,
                    value: pace,
                    unit: "min/km",
                    sessionId: sessionId
                )
            } else if fetchPR(userId: userId, exerciseName: exerciseName, type: .fastestPace) == nil {
                return PersonalRecord(
                    userId: userId,
                    exerciseName: exerciseName,
                    recordType: .fastestPace,
                    value: pace,
                    unit: "min/km",
                    sessionId: sessionId
                )
            }
        }

        return nil
    }

    func fetchSessionsForDate(_ date: Date, userId: String) -> [WorkoutSession] {
        let start = Self.dayStart(for: date)
        let end = Self.dayEnd(for: date)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.userId == userId
                    && session.startedAt >= start
                    && session.startedAt < end
            },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func fetchTemplatesScheduled(for date: Date, userId: String) -> [WorkoutTemplate] {
        let start = Self.dayStart(for: date)
        let end = Self.dayEnd(for: date)
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { template in
                template.userId == userId
                    && template.nextScheduledAt != nil
                    && template.nextScheduledAt! >= start
                    && template.nextScheduledAt! < end
            },
            sortBy: [SortDescriptor(\.nextScheduledAt)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    // MARK: - Habits

    func fetchHabitsForUser(_ userId: String) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.userId == userId && $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func fetchCompletionsForHabit(_ habitId: UUID, in range: DateInterval) -> [HabitCompletion] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { completion in
                completion.habitId == habitId
                    && completion.completedDate >= start
                    && completion.completedDate <= end
            },
            sortBy: [SortDescriptor(\.completedDate, order: .reverse)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func streakForHabit(_ habitId: UUID) -> Int {
        let calendar = Calendar.current
        let distantPast = Date.distantPast
        let now = Date.now
        let completions = fetchCompletionsForHabit(
            habitId,
            in: DateInterval(start: distantPast, end: now)
        )

        let completionDays = Set(
            completions.map { calendar.startOfDay(for: $0.completedDate) }
        )

        var streak = 0
        var checkDate = calendar.startOfDay(for: now)

        if !completionDays.contains(checkDate),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            checkDate = yesterday
        }

        while completionDays.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    // MARK: - Tasks

    func fetchTasksDueToday(userId: String) -> [TaskRecord] {
        let start = Self.dayStart(for: .now)
        let end = Self.dayEnd(for: .now)
        let descriptor = FetchDescriptor<TaskRecord>(
            predicate: #Predicate { task in
                task.userId == userId
                    && task.isComplete == false
                    && task.dueDate != nil
                    && task.dueDate! >= start
                    && task.dueDate! < end
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    // MARK: - Sync

    func fetchUnsyncedRecords<T: SyncTrackable>(of type: T.Type) -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.synced == false }
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    func markSynced<T: SyncTrackable>(_ records: [T]) {
        records.forEach { $0.synced = true }
        try? mainContext.save()
    }

    // MARK: - Water

    func waterLoggedToday(userId: String) -> Int {
        let start = Self.dayStart(for: .now)
        let end = Self.dayEnd(for: .now)
        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { log in
                log.userId == userId
                    && log.loggedAt >= start
                    && log.loggedAt < end
            }
        )
        let logs = (try? mainContext.fetch(descriptor)) ?? []
        return logs.reduce(0) { $0 + $1.amountMl }
    }

    func fetchWaterGoal(for userId: String) -> WaterGoal? {
        let descriptor = FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.dailyGoalMl, order: .reverse)]
        )
        return try? mainContext.fetch(descriptor).first
    }

    func userProfileExists(userId: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func deleteAllData(for userId: String, context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        ))
        profiles.forEach { context.delete($0) }

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.userId == userId }
        ))
        sessions.forEach { context.delete($0) }

        let sets = try context.fetch(FetchDescriptor<ExerciseSet>(
            predicate: #Predicate { $0.userId == userId }
        ))
        sets.forEach { context.delete($0) }

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.userId == userId }
        ))
        templates.forEach { context.delete($0) }

        let missed = try context.fetch(FetchDescriptor<MissedWorkout>(
            predicate: #Predicate { $0.userId == userId }
        ))
        missed.forEach { context.delete($0) }

        let records = try context.fetch(FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.userId == userId }
        ))
        records.forEach { context.delete($0) }

        let bodyWeights = try context.fetch(FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.userId == userId }
        ))
        bodyWeights.forEach { context.delete($0) }

        let habits = try context.fetch(FetchDescriptor<Habit>(
            predicate: #Predicate { $0.userId == userId }
        ))
        habits.forEach { context.delete($0) }

        let completions = try context.fetch(FetchDescriptor<HabitCompletion>(
            predicate: #Predicate { $0.userId == userId }
        ))
        completions.forEach { context.delete($0) }

        let tasks = try context.fetch(FetchDescriptor<TaskRecord>(
            predicate: #Predicate { $0.userId == userId }
        ))
        tasks.forEach { context.delete($0) }

        let moods = try context.fetch(FetchDescriptor<MoodCheckin>(
            predicate: #Predicate { $0.userId == userId }
        ))
        moods.forEach { context.delete($0) }

        let waterLogs = try context.fetch(FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.userId == userId }
        ))
        waterLogs.forEach { context.delete($0) }

        let waterGoals = try context.fetch(FetchDescriptor<WaterGoal>(
            predicate: #Predicate { $0.userId == userId }
        ))
        waterGoals.forEach { context.delete($0) }

        UserDefaults.standard.removeObject(forKey: "trainingDaysPerWeek_\(userId)")
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
        try context.save()
    }

    // MARK: - Writes (offline-first)

    func insert<T: PersistentModel>(_ model: T) {
        mainContext.insert(model)
        try? mainContext.save()
    }

    func delete<T: PersistentModel>(_ model: T) {
        mainContext.delete(model)
        try? mainContext.save()
    }

    func save() {
        try? mainContext.save()
    }

    // MARK: - Helpers

    private static func dayStart(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func dayEnd(for date: Date) -> Date {
        let start = dayStart(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }
}
