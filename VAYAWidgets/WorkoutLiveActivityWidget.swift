import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            WorkoutLiveActivityLockView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.82))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.workoutName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.exerciseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                if let rest = context.state.restSecondsRemaining, rest > 0 {
                    Text("\(rest)s")
                        .font(.caption2.monospacedDigit())
                } else {
                    Text(formatElapsed(context.state.elapsedSeconds))
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct WorkoutLiveActivityLockView: View {
    let context: ActivityViewContext<WorkoutLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.workoutName)
                    .font(.headline)
                Text(context.state.exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(context.state.setLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.75, green: 0.35, blue: 0.95))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatElapsed(context.state.elapsedSeconds))
                    .font(.title3.monospacedDigit().weight(.bold))
                if let rest = context.state.restSecondsRemaining, rest > 0 {
                    Text("Rest \(rest)s")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VAYAWidgetPalette.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
