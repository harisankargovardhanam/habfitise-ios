import Foundation
import Observation

@Observable
@MainActor
final class WorkoutViewModel {
    var sessions: [WorkoutSessionSummary] = []
    var isActiveSession = false

    struct WorkoutSessionSummary: Identifiable {
        let id: UUID
        let title: String
        let date: Date
        let exerciseCount: Int
    }

    func loadSampleData() {
        sessions = [
            WorkoutSessionSummary(id: UUID(), title: "Upper Body", date: .now, exerciseCount: 6),
            WorkoutSessionSummary(id: UUID(), title: "Leg Day", date: .now.addingTimeInterval(-86400), exerciseCount: 5)
        ]
    }
}
