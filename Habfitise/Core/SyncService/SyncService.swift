import Foundation
import Network
import Observation
import Supabase
import SwiftData

@Observable
@MainActor
final class SyncService {
    var syncStatus: SyncStatus = .idle
    var syncPhase: SyncPhase = .idle

    private let batchSize = AppConstants.Sync.batchSize
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.habfitise.sync.network", qos: .utility)

    private var isSyncInFlight = false
    private var isMonitoringNetwork = false
    private var wasOffline = true
    private var modelContext: ModelContext?
    private var userIdProvider: (@MainActor () -> String?)?

    init() {}

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Configuration

    func configure(modelContext: ModelContext, userIdProvider: @escaping @MainActor () -> String?) {
        self.modelContext = modelContext
        self.userIdProvider = userIdProvider
    }

    func startNetworkMonitoring() {
        guard !isMonitoringNetwork else { return }
        isMonitoringNetwork = true

        wasOffline = pathMonitor.currentPath.status != .satisfied

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if isOnline, self.wasOffline {
                    await self.syncAllFromMonitor()
                }
                self.wasOffline = !isOnline
            }
        }

        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public Sync

    /// Pulls cloud data down, then pushes local unsynced changes up.
    func syncAll(modelContext: ModelContext, userId: String?, showProgress: Bool = false) async {
        guard !AppConstants.Backend.useLocalOnly else { return }
        guard !isSyncInFlight else { return }

        guard SupabaseManager.shared.isConfigured, SupabaseManager.shared.client != nil else {
            syncStatus = .error(SyncServiceError.notConfigured.localizedDescription)
            return
        }

        guard let userId, !userId.isEmpty else { return }

        isSyncInFlight = true
        syncStatus = .syncing
        if showProgress {
            syncPhase = .connecting
        }

        do {
            if showProgress {
                syncPhase = .downloading
            }
            try await pullAllChanges(userId: userId, modelContext: modelContext, showProgress: showProgress)

            if showProgress {
                syncPhase = .uploading
            }
            try await pushAllPendingChanges(modelContext: modelContext)

            SyncPullMapper.applyUserDefaults(from: userId, context: modelContext)

            if showProgress {
                syncPhase = .finishing
            }
            syncStatus = .idle
            syncPhase = .idle
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt
            )
        } catch {
            syncStatus = .error(error.localizedDescription)
            syncPhase = .idle
        }

        isSyncInFlight = false
    }

    var lastErrorMessage: String? {
        if case let .error(message) = syncStatus {
            return message
        }
        return nil
    }

    // MARK: - Pull Pipeline

    private func pullAllChanges(
        userId: String,
        modelContext: ModelContext,
        showProgress: Bool
    ) async throws {
        guard let client = SupabaseManager.shared.client else {
            throw SyncServiceError.notConfigured
        }

        let steps: [(SyncPhase, String, () async throws -> Void)] = [
            (.downloadingProfile, SyncTable.userProfiles, {
                let rows: [UserProfileDTO] = try await self.fetchProfile(userId: userId, client: client)
                try SyncPullMapper.applyUserProfiles(rows, context: modelContext)
            }),
            (.downloadingWorkouts, SyncTable.workoutSessions, {
                let rows: [WorkoutSessionDTO] = try await self.fetch(table: SyncTable.workoutSessions, userId: userId, client: client)
                try SyncPullMapper.applyWorkoutSessions(rows, context: modelContext)
            }),
            (.downloadingSets, SyncTable.workoutSets, {
                let rows: [ExerciseSetDTO] = try await self.fetch(table: SyncTable.workoutSets, userId: userId, client: client)
                try SyncPullMapper.applyExerciseSets(rows, context: modelContext)
            }),
            (.downloadingHabits, SyncTable.habits, {
                let rows: [HabitDTO] = try await self.fetch(table: SyncTable.habits, userId: userId, client: client)
                try SyncPullMapper.applyHabits(rows, context: modelContext)
            }),
            (.downloadingHabitCompletions, SyncTable.habitCompletions, {
                let rows: [HabitCompletionDTO] = try await self.fetch(table: SyncTable.habitCompletions, userId: userId, client: client)
                try SyncPullMapper.applyHabitCompletions(rows, context: modelContext)
            }),
            (.downloadingTasks, SyncTable.tasks, {
                let rows: [TaskRecordDTO] = try await self.fetch(table: SyncTable.tasks, userId: userId, client: client)
                try SyncPullMapper.applyTasks(rows, context: modelContext)
            }),
            (.downloadingMood, SyncTable.moodCheckins, {
                let rows: [MoodCheckinDTO] = try await self.fetch(table: SyncTable.moodCheckins, userId: userId, client: client)
                try SyncPullMapper.applyMoodCheckins(rows, context: modelContext)
            }),
            (.downloadingWater, SyncTable.waterLogs, {
                let rows: [WaterLogDTO] = try await self.fetch(table: SyncTable.waterLogs, userId: userId, client: client)
                try SyncPullMapper.applyWaterLogs(rows, context: modelContext)
            }),
            (.downloadingWaterGoals, SyncTable.waterGoals, {
                let rows: [WaterGoalDTO] = try await self.fetch(table: SyncTable.waterGoals, userId: userId, client: client)
                try SyncPullMapper.applyWaterGoals(rows, context: modelContext)
            })
        ]

        for (phase, _, pull) in steps {
            if showProgress {
                syncPhase = phase
            }
            do {
                try await pull()
            } catch {
                // Table may not exist yet in Supabase — skip and continue restore.
                if Self.isMissingTableError(error) {
                    continue
                }
                throw error
            }
        }
    }

    private func fetchProfile(
        userId: String,
        client: SupabaseClient
    ) async throws -> [UserProfileDTO] {
        try await client
            .from(SyncTable.userProfiles)
            .select()
            .eq("id", value: userId)
            .execute()
            .value
    }

    private func fetch<T: Decodable>(
        table: String,
        userId: String,
        client: SupabaseClient
    ) async throws -> [T] {
        try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    private static func isMissingTableError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("does not exist")
            || message.contains("relation")
            || message.contains("404")
            || message.contains("not found")
    }

    // MARK: - Push Pipeline

    private func pushAllPendingChanges(modelContext: ModelContext) async throws {
        guard let client = SupabaseManager.shared.client else {
            throw SyncServiceError.notConfigured
        }

        try await push(
            UserProfile.self,
            table: SyncTable.userProfiles,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.userProfile($0) }

        try await push(
            WorkoutSession.self,
            table: SyncTable.workoutSessions,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.workoutSession($0) }

        try await push(
            ExerciseSet.self,
            table: SyncTable.workoutSets,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.exerciseSet($0) }

        try await push(
            Habit.self,
            table: SyncTable.habits,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.habit($0) }

        try await push(
            HabitCompletion.self,
            table: SyncTable.habitCompletions,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.habitCompletion($0) }

        try await push(
            TaskRecord.self,
            table: SyncTable.tasks,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.task($0) }

        try await push(
            MoodCheckin.self,
            table: SyncTable.moodCheckins,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.moodCheckin($0) }

        try await push(
            WaterLog.self,
            table: SyncTable.waterLogs,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.waterLog($0) }

        try await push(
            WaterGoal.self,
            table: SyncTable.waterGoals,
            context: modelContext,
            client: client
        ) { SyncDTOMapper.waterGoal($0) }
    }

    private func push<T: SyncTrackable, D: Encodable>(
        _ type: T.Type,
        table: String,
        context: ModelContext,
        client: SupabaseClient,
        map: (T) -> D
    ) async throws {
        let pending = fetchUnsynced(type, context: context)
        guard !pending.isEmpty else { return }

        for batch in pending.chunked(into: batchSize) {
            let rows = batch.map(map)
            do {
                try await client
                    .from(table)
                    .upsert(rows, onConflict: "id", ignoreDuplicates: false)
                    .execute()
            } catch {
                if Self.isMissingTableError(error) {
                    return
                }
                throw error
            }

            for record in batch {
                record.synced = true
            }
            try context.save()
        }
    }

    private func fetchUnsynced<T: SyncTrackable>(
        _ type: T.Type,
        context: ModelContext
    ) -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.synced == false },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Network Callback

    private func syncAllFromMonitor() async {
        guard let modelContext, let userId = userIdProvider?() else { return }
        await syncAll(modelContext: modelContext, userId: userId)
    }
}

// MARK: - Errors

enum SyncServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
        }
    }
}

// MARK: - Batch Helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count / size) + 1)
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}

// MARK: - Local Write Helper

extension SyncTrackable {
    /// Mark a record dirty for the next sync pass (offline-first).
    @MainActor
    func markPendingSync() {
        synced = false
        updatedAt = .now
    }
}
