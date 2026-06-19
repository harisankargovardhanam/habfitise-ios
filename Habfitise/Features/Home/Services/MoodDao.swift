import Foundation
import SwiftData

enum MoodDao {
    @MainActor
    static func saveCheckin(userId: String, moodIndex: Int, context: ModelContext) {
        let score = moodIndex + 1
        let checkin = MoodCheckin(
            userId: userId,
            energyScore: score,
            moodScore: score,
            synced: false
        )
        context.insert(checkin)
        try? context.save()
    }

    @MainActor
    static func todayCheckin(userId: String, context: ModelContext) -> MoodCheckin? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }

        let userIdConst = userId
        let descriptor = FetchDescriptor<MoodCheckin>(
            predicate: #Predicate { checkin in
                checkin.userId == userIdConst
                    && checkin.createdAt >= today
                    && checkin.createdAt < tomorrow
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }
}
