import Foundation

enum DashboardWidget: String, Identifiable, CaseIterable, Codable, Hashable {
    case activity
    case workout
    case water
    case habits
    case tasks
    case weight
    case streak
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: "Activity"
        case .workout: "Today's Workout"
        case .water: "Water"
        case .habits: "Habits"
        case .tasks: "Tasks"
        case .weight: "Weight"
        case .streak: "Streak"
        case .energy: "Energy Check-in"
        }
    }

    var accent: BentoCardAccent {
        switch self {
        case .activity: .activity
        case .workout: .workout
        case .water: .water
        case .habits: .habits
        case .tasks: .tasks
        case .weight: .bodyWeight
        case .streak: .streak
        case .energy: .mood
        }
    }

    var systemImage: String { accent.systemImage }

    /// Fixed home dashboard order — no drag/reorder.
    static let homeLayout: [DashboardWidget] = [
        .workout, .activity, .water, .habits, .tasks, .streak, .weight, .energy
    ]
}
