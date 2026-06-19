import Foundation
import Network
import Observation
import Supabase
import SwiftData

/// Offline-first sync: SwiftData is source of truth; Supabase is cloud backup + cross-device sync.
///
/// Inject into the view hierarchy (iOS 17+ `@Observable` pattern):
/// ```swift
/// @State private var syncService = SyncService()
/// // ...
/// MainTabView()
///     .environment(syncService)
/// ```
/// Legacy `@EnvironmentObject` equivalent: `@Environment(SyncService.self) private var syncService`
@Observable
@MainActor
final class SyncService {
    var syncStatus: SyncStatus = .idle

    private let batchSize = AppConstants.Sync.batchSize
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.habfitise.sync.network", qos: .utility)

    private var isSyncInFlight = false
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

    func syncAll(modelContext: ModelContext, userId: String?) async {
        guard !AppConstants.Backend.useLocalOnly else { return }
        guard !isSyncInFlight else { return }

        guard SupabaseManager.shared.isConfigured, SupabaseManager.shared.client != nil else {
            syncStatus = .error(SyncServiceError.notConfigured.localizedDescription)
            return
        }

        guard let userId, !userId.isEmpty else { return }

        isSyncInFlight = true
        syncStatus = .syncing

        do {
            try await pushAllPendingChanges(modelContext: modelContext)
            syncStatus = .idle
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.lastSuccessfulSyncAt)
        } catch {
            syncStatus = .error(error.localizedDescription)
        }

        isSyncInFlight = false
    }

    var lastErrorMessage: String? {
        if case let .error(message) = syncStatus {
            return message
        }
        return nil
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
            try await client
                .from(table)
                .upsert(rows, onConflict: "id", ignoreDuplicates: false)
                .execute()

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
