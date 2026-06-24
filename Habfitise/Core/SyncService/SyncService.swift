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
    private var isNetworkReachable = false
    private var modelContext: ModelContext?
    private var userIdProvider: (@MainActor () -> String?)?
    private var cloudSyncEnabled: (@MainActor () -> Bool)?
    private var lastSyncAttemptAt: Date?
    private var lastSyncAttemptUserId: String?

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init() {}

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Configuration

    func configure(
        modelContext: ModelContext,
        userIdProvider: @escaping @MainActor () -> String?,
        cloudSyncEnabled: @escaping @MainActor () -> Bool = { false }
    ) {
        self.modelContext = modelContext
        self.userIdProvider = userIdProvider
        self.cloudSyncEnabled = cloudSyncEnabled
    }

    func startNetworkMonitoring() {
        guard !isMonitoringNetwork else { return }
        isMonitoringNetwork = true

        wasOffline = pathMonitor.currentPath.status != .satisfied
        isNetworkReachable = !wasOffline

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                self.isNetworkReachable = isOnline
                if isOnline, self.wasOffline {
                    await self.syncAllFromMonitor()
                }
                self.wasOffline = !isOnline
            }
        }

        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public Sync

    /// Primary sync entry — incremental by default, debounced unless `force`.
    func sync(
        modelContext: ModelContext,
        userId: String?,
        mode: SyncMode = .incremental,
        scope: SyncScope = .all,
        showProgress: Bool = false,
        force: Bool = false
    ) async {
        guard allowsCloudSync else { return }
        guard !isSyncInFlight else { return }

        guard SupabaseManager.shared.isConfigured, SupabaseManager.shared.client != nil else {
            syncStatus = .error(SyncServiceError.notConfigured.localizedDescription)
            return
        }

        guard let userId, !userId.isEmpty else { return }

        let normalizedUserId = userId.lowercased()
        if shouldDebounce(userId: normalizedUserId, force: force) {
            return
        }

        isSyncInFlight = true
        lastSyncAttemptAt = .now
        lastSyncAttemptUserId = normalizedUserId
        syncStatus = .syncing
        if showProgress {
            syncPhase = .connecting
        }

        let pullOptions = pullOptions(for: mode)
        let since = incrementalSince(for: mode, userId: normalizedUserId)
        let tables = scope.tableKinds

        do {
            if showProgress {
                syncPhase = .uploading
            }
            try await pushAllPendingChanges(modelContext: modelContext, userId: normalizedUserId)

            if showProgress {
                syncPhase = .downloading
            }
            try await pullScopedChanges(
                tables: tables,
                userId: normalizedUserId,
                modelContext: modelContext,
                showProgress: showProgress,
                since: since,
                pullOptions: pullOptions
            )

            SyncPullMapper.applyUserDefaults(from: normalizedUserId, context: modelContext)

            if showProgress {
                syncPhase = .finishing
            }
            syncStatus = .idle
            syncPhase = .idle
            SyncTimestampStore.markSyncSucceeded(for: normalizedUserId)
        } catch {
            syncStatus = .error(Self.friendlySyncMessage(error.localizedDescription))
            syncPhase = .idle
        }

        isSyncInFlight = false
    }

    /// Push local writes and queued deletes immediately (no pull). Call after create/update/delete.
    func pushPendingChanges(modelContext: ModelContext, userId: String?) async {
        guard allowsCloudSync else { return }
        guard let userId, !userId.isEmpty else { return }

        guard SupabaseManager.shared.isConfigured, SupabaseManager.shared.client != nil else {
            syncStatus = .error(SyncServiceError.notConfigured.localizedDescription)
            return
        }

        var waitAttempts = 0
        while isSyncInFlight, waitAttempts < 120 {
            try? await Task.sleep(for: .milliseconds(100))
            waitAttempts += 1
        }

        isSyncInFlight = true
        syncStatus = .syncing

        do {
            try await pushAllPendingChanges(
                modelContext: modelContext,
                userId: userId.lowercased()
            )
            syncStatus = .idle
        } catch {
            if Self.isNetworkError(error) {
                syncStatus = .idle
            } else {
                syncStatus = .error(Self.friendlySyncMessage(error.localizedDescription))
            }
        }

        isSyncInFlight = false
    }

    /// Fire-and-forget push after a local mutation. Skips when offline; reconnect sync flushes the queue.
    func schedulePush(modelContext: ModelContext, userId: String?) {
        guard allowsCloudSync else { return }
        guard let userId, !userId.isEmpty else { return }

        if !isNetworkReachable {
            return
        }

        Task { @MainActor in
            await pushPendingChanges(modelContext: modelContext, userId: userId)
        }
    }

    /// Full sync of all tables (login, onboarding). Bypasses debounce.
    func syncAll(
        modelContext: ModelContext,
        userId: String?,
        showProgress: Bool = false,
        pullOptions: SyncPullOptions = .standard
    ) async {
        let mode: SyncMode = pullOptions.reconcileDeletions ? .refresh : .full
        await sync(
            modelContext: modelContext,
            userId: userId,
            mode: mode,
            scope: .all,
            showProgress: showProgress,
            force: true
        )
    }

    /// User-initiated pull-to-refresh — scoped full pull + delete reconcile.
    func refresh(
        modelContext: ModelContext,
        userId: String?,
        scope: SyncScope = .all
    ) async {
        guard allowsCloudSync else { return }

        var waitAttempts = 0
        while isSyncInFlight, waitAttempts < 120 {
            try? await Task.sleep(for: .milliseconds(100))
            waitAttempts += 1
        }

        await sync(
            modelContext: modelContext,
            userId: userId,
            mode: .refresh,
            scope: scope,
            force: true
        )
    }

    var lastErrorMessage: String? {
        if case let .error(message) = syncStatus {
            return message
        }
        return nil
    }

    var userFacingStatusMessage: String? {
        if let friendly = lastErrorMessage.map({ Self.friendlySyncMessage($0) }) {
            return friendly
        }
        return nil
    }

    private var allowsCloudSync: Bool {
        guard !AppConstants.Backend.useLocalOnly else { return false }
        return cloudSyncEnabled?() ?? false
    }

    // MARK: - Pull Pipeline

    private func shouldDebounce(userId: String, force: Bool) -> Bool {
        guard !force else { return false }
        guard lastSyncAttemptUserId == userId, let lastSyncAttemptAt else { return false }
        return Date.now.timeIntervalSince(lastSyncAttemptAt) < AppConstants.Sync.minimumIntervalSeconds
    }

    private func pullOptions(for mode: SyncMode) -> SyncPullOptions {
        switch mode {
        case .full, .incremental:
            return .standard
        case .refresh:
            return .refresh
        }
    }

    private func incrementalSince(for mode: SyncMode, userId: String) -> Date? {
        switch mode {
        case .full, .refresh:
            return nil
        case .incremental:
            return SyncTimestampStore.incrementalSince(for: userId)
        }
    }

    private func pullScopedChanges(
        tables: [SyncTableKind],
        userId: String,
        modelContext: ModelContext,
        showProgress: Bool,
        since: Date?,
        pullOptions: SyncPullOptions
    ) async throws {
        guard let client = SupabaseManager.shared.client else {
            throw SyncServiceError.notConfigured
        }

        for kind in tables {
            if showProgress, let phase = syncPhase(for: kind) {
                syncPhase = phase
            }
            do {
                try await pullTable(
                    kind,
                    userId: userId,
                    client: client,
                    modelContext: modelContext,
                    since: since,
                    pullOptions: pullOptions
                )
            } catch {
                if Self.isMissingTableError(error) {
                    continue
                }
                throw error
            }
        }
    }

    private func syncPhase(for kind: SyncTableKind) -> SyncPhase? {
        switch kind {
        case .profile: .downloadingProfile
        case .workoutSessions: .downloadingWorkouts
        case .workoutSets: .downloadingSets
        case .habits: .downloadingHabits
        case .habitCompletions: .downloadingHabitCompletions
        case .tasks: .downloadingTasks
        case .moodCheckins: .downloadingMood
        case .waterLogs: .downloadingWater
        case .waterGoals: .downloadingWaterGoals
        }
    }

    private func pullTable(
        _ kind: SyncTableKind,
        userId: String,
        client: SupabaseClient,
        modelContext: ModelContext,
        since: Date?,
        pullOptions: SyncPullOptions
    ) async throws {
        switch kind {
        case .profile:
            let rows = try await fetchProfile(userId: userId, client: client, since: since)
            try SyncPullMapper.applyUserProfiles(rows, userId: userId, context: modelContext, options: pullOptions)
        case .workoutSessions:
            let rows: [WorkoutSessionDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyWorkoutSessions(rows, userId: userId, context: modelContext, options: pullOptions)
        case .workoutSets:
            let rows: [ExerciseSetDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyExerciseSets(rows, userId: userId, context: modelContext, options: pullOptions)
        case .habits:
            let rows: [HabitDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyHabits(rows, userId: userId, context: modelContext, options: pullOptions)
        case .habitCompletions:
            let rows: [HabitCompletionDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyHabitCompletions(rows, userId: userId, context: modelContext, options: pullOptions)
        case .tasks:
            let rows: [TaskRecordDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyTasks(rows, userId: userId, context: modelContext, options: pullOptions)
        case .moodCheckins:
            let rows: [MoodCheckinDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyMoodCheckins(rows, userId: userId, context: modelContext, options: pullOptions)
        case .waterLogs:
            let rows: [WaterLogDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyWaterLogs(rows, userId: userId, context: modelContext, options: pullOptions)
        case .waterGoals:
            let rows: [WaterGoalDTO] = try await fetch(table: kind.tableName, userId: userId, client: client, since: since)
            try SyncPullMapper.applyWaterGoals(rows, userId: userId, context: modelContext, options: pullOptions)
        }
    }

    private func fetch<T: Decodable>(
        table: String,
        userId: String,
        client: SupabaseClient,
        since: Date? = nil
    ) async throws -> [T] {
        var query = client
            .from(table)
            .select()
            .eq("user_id", value: userId.lowercased())

        if let since {
            query = query.gte("updated_at", value: Self.iso8601Formatter.string(from: since))
        }

        return try await query.execute().value
    }

    private static func friendlySyncMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("row-level security") || lower.contains("policy for table") {
            return "Couldn't sync account settings. Continuing on this device."
        }
        if lower.contains("not configured") {
            return "Cloud sync isn't set up yet."
        }
        if lower.contains("network") || lower.contains("internet") || lower.contains("offline") {
            return "You're offline. Data stays on this device."
        }
        return "Sync paused. You can keep using the app."
    }

    private static func isMissingTableError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("does not exist")
            || message.contains("relation")
            || message.contains("404")
            || message.contains("not found")
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                break
            }
        }

        let message = error.localizedDescription.lowercased()
        return message.contains("network")
            || message.contains("internet")
            || message.contains("offline")
            || message.contains("connection")
            || message.contains("timed out")
    }

    // MARK: - Push Pipeline

    private func pushAllPendingChanges(modelContext: ModelContext, userId: String) async throws {
        guard let client = SupabaseManager.shared.client else {
            throw SyncServiceError.notConfigured
        }

        let authUserId = userId.lowercased()

        try await pushPendingDeletions(userId: authUserId, client: client)

        try await pushUserProfiles(
            context: modelContext,
            client: client,
            userId: authUserId
        )

        try await push(
            WorkoutSession.self,
            table: SyncTable.workoutSessions,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.workoutSession($0) }

        try await push(
            ExerciseSet.self,
            table: SyncTable.workoutSets,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.exerciseSet($0) }

        try await push(
            Habit.self,
            table: SyncTable.habits,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.habit($0) }

        try await push(
            HabitCompletion.self,
            table: SyncTable.habitCompletions,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.habitCompletion($0) }

        try await push(
            TaskRecord.self,
            table: SyncTable.tasks,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.task($0) }

        try await push(
            MoodCheckin.self,
            table: SyncTable.moodCheckins,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.moodCheckin($0) }

        try await push(
            WaterLog.self,
            table: SyncTable.waterLogs,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.waterLog($0) }

        try await push(
            WaterGoal.self,
            table: SyncTable.waterGoals,
            context: modelContext,
            client: client,
            userId: authUserId
        ) { SyncDTOMapper.waterGoal($0) }
    }

    private func fetchProfile(
        userId: String,
        client: SupabaseClient,
        since: Date? = nil
    ) async throws -> [UserProfileDTO] {
        let normalizedUserId = userId.lowercased()

        func query(byUserIdColumn idColumn: String) async throws -> [UserProfileDTO] {
            var builder = client
                .from(SyncTable.userProfiles)
                .select()
                .eq(idColumn, value: normalizedUserId)

            if let since {
                builder = builder.gte("updated_at", value: Self.iso8601Formatter.string(from: since))
            }

            return try await builder.execute().value
        }

        let byPrimaryId = try await query(byUserIdColumn: "id")
        if !byPrimaryId.isEmpty {
            return byPrimaryId
        }

        return try await query(byUserIdColumn: "user_id")
    }

    private func pushPendingDeletions(userId: String, client: SupabaseClient) async throws {
        let pending = SyncDeletionQueue.peek(userId: userId)
        guard !pending.isEmpty else { return }

        var succeeded: [SyncDeletionQueue.Entry] = []
        var lastError: Error?

        let grouped = Dictionary(grouping: pending, by: \.table)
        for (table, entries) in grouped {
            for batch in entries.chunked(into: batchSize) {
                do {
                    try await client
                        .from(table)
                        .delete()
                        .in("id", values: batch.map(\.id))
                        .execute()
                    succeeded.append(contentsOf: batch)
                } catch {
                    if Self.isMissingTableError(error) {
                        SyncDeletionQueue.clear(userId: userId)
                        return
                    }
                    lastError = error
                }
            }
        }

        SyncDeletionQueue.remove(userId: userId, entries: succeeded)

        if let lastError, !SyncDeletionQueue.peek(userId: userId).isEmpty {
            throw lastError
        }
    }

    private func pushUserProfiles(
        context: ModelContext,
        client: SupabaseClient,
        userId: String
    ) async throws {
        let pending = fetchUnsyncedProfiles(userId: userId, context: context)
        guard !pending.isEmpty else { return }

        for batch in pending.chunked(into: batchSize) {
            let rows = batch.map { SyncDTOMapper.userProfile($0, authUserId: userId) }
            do {
                try await client
                    .from(SyncTable.userProfiles)
                    .upsert(rows, onConflict: "id", ignoreDuplicates: false)
                    .execute()
            } catch {
                if Self.isMissingTableError(error) {
                    return
                }
                throw error
            }

            for profile in batch {
                profile.synced = true
                profile.userId = userId.lowercased()
            }
            try context.save()
        }
    }

    private func push<T: SyncTrackable, D: Encodable>(
        _ type: T.Type,
        table: String,
        context: ModelContext,
        client: SupabaseClient,
        userId: String,
        map: (T) -> D
    ) async throws {
        let pending = fetchUnsynced(type, userId: userId, context: context)
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
                normalizeUserId(for: record, authUserId: userId)
            }
            try context.save()
        }
    }

    private func normalizeUserId(for record: some SyncTrackable, authUserId: String) {
        let normalized = authUserId.lowercased()
        switch record {
        case let profile as UserProfile:
            profile.userId = normalized
        case let session as WorkoutSession:
            session.userId = normalized
        case let set as ExerciseSet:
            set.userId = normalized
        case let habit as Habit:
            habit.userId = normalized
        case let completion as HabitCompletion:
            completion.userId = normalized
        case let task as TaskRecord:
            task.userId = normalized
        case let mood as MoodCheckin:
            mood.userId = normalized
        case let waterLog as WaterLog:
            waterLog.userId = normalized
        case let waterGoal as WaterGoal:
            waterGoal.userId = normalized
        default:
            break
        }
    }

    private func fetchUnsynced<T: SyncTrackable>(
        _ type: T.Type,
        userId: String,
        context: ModelContext
    ) -> [T] {
        if type == UserProfile.self {
            return fetchUnsyncedProfiles(userId: userId, context: context) as? [T] ?? []
        }

        let userIdConst = userId
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { record in
                record.synced == false
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { syncUserId(for: $0)?.lowercased() == userIdConst }
    }

    private func fetchUnsyncedProfiles(userId: String, context: ModelContext) -> [UserProfile] {
        let userIdConst = userId.lowercased()
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.synced == false
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.userId.lowercased() == userIdConst }
    }

    private func syncUserId(for record: some SyncTrackable) -> String? {
        switch record {
        case let profile as UserProfile:
            return profile.userId
        case let session as WorkoutSession:
            return session.userId
        case let set as ExerciseSet:
            return set.userId
        case let habit as Habit:
            return habit.userId
        case let completion as HabitCompletion:
            return completion.userId
        case let task as TaskRecord:
            return task.userId
        case let mood as MoodCheckin:
            return mood.userId
        case let waterLog as WaterLog:
            return waterLog.userId
        case let waterGoal as WaterGoal:
            return waterGoal.userId
        default:
            return nil
        }
    }

    // MARK: - Network Callback

    private func syncAllFromMonitor() async {
        guard let modelContext, let userId = userIdProvider?() else { return }

        var waitAttempts = 0
        while isSyncInFlight, waitAttempts < 120 {
            try? await Task.sleep(for: .milliseconds(100))
            waitAttempts += 1
        }

        await sync(
            modelContext: modelContext,
            userId: userId,
            mode: .incremental,
            scope: .all,
            force: true
        )
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
