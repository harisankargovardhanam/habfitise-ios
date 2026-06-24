import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var updatedAt: Date

    var tasks: [WidgetTaskItem]
    var habits: [WidgetHabitItem]

    var waterTodayML: Int
    var waterGoalML: Int
    var filledWaterGlasses: Int
    var waterGlassCount: Int

    var habitsDone: Int
    var habitsTotal: Int
    var openTaskCount: Int
    var dayStreak: Int

    static let empty = WidgetSnapshot(
        updatedAt: .distantPast,
        tasks: [],
        habits: [],
        waterTodayML: 0,
        waterGoalML: 2_000,
        filledWaterGlasses: 0,
        waterGlassCount: 8,
        habitsDone: 0,
        habitsTotal: 0,
        openTaskCount: 0,
        dayStreak: 0
    )
}

struct WidgetTaskItem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let isComplete: Bool
}

struct WidgetHabitItem: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let isCompleted: Bool
}

enum WidgetSnapshotStore {
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSharedConstants.appGroupIdentifier)
    }

    static func load() -> WidgetSnapshot {
        guard
            let data = sharedDefaults?.data(forKey: WidgetSharedConstants.snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: WidgetSharedConstants.snapshotKey)
    }
}
