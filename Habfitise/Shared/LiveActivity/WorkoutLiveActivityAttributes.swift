import ActivityKit
import Foundation

struct WorkoutLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setLabel: String
        var restSecondsRemaining: Int?
        var elapsedSeconds: Int
    }

    var workoutName: String
}

@MainActor
enum WorkoutLiveActivityManager {
    private static var currentActivity: Activity<WorkoutLiveActivityAttributes>?

    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(workoutName: String, exerciseName: String, setLabel: String) {
        guard isSupported else { return }
        end()

        let attributes = WorkoutLiveActivityAttributes(workoutName: workoutName)
        let state = WorkoutLiveActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setLabel: setLabel,
            restSecondsRemaining: nil,
            elapsedSeconds: 0
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            currentActivity = nil
        }
    }

    static func update(
        exerciseName: String,
        setLabel: String,
        restSecondsRemaining: Int?,
        elapsedSeconds: Int
    ) {
        guard let activity = currentActivity else { return }

        let state = WorkoutLiveActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setLabel: setLabel,
            restSecondsRemaining: restSecondsRemaining,
            elapsedSeconds: elapsedSeconds
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    static func end() {
        guard let activity = currentActivity else { return }
        currentActivity = nil

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
