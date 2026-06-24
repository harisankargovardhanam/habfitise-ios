import SwiftUI
import WidgetKit

struct ActivityWidget: Widget {
    let kind = "VAYAActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VAYAWidgetProvider()) { entry in
            ActivityWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Daily Movement")
        .description("Steps, workout status, and wellness score.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ActivityWidgetView: View {
    let entry: VAYAWidgetEntry

    var body: some View {
        let snapshot = entry.snapshot
        let stepProgress = snapshot.stepGoal > 0
            ? min(Double(snapshot.stepsToday) / Double(snapshot.stepGoal), 1)
            : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Movement", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.wellnessScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.accent)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.stepsToday.formatted())")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("steps")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: stepProgress)
                .tint(Color(red: 1, green: 0.22, blue: 0.37))

            HStack {
                if snapshot.workoutDoneToday {
                    Label("\(snapshot.workoutMinutesToday)m workout", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.75, green: 0.35, blue: 0.95))
                } else {
                    Text("No workout yet today")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(14)
    }
}

#if DEBUG
struct ActivityWidget_Previews: PreviewProvider {
    static var previews: some View {
        ActivityWidgetView(
            entry: VAYAWidgetEntry(
                date: .now,
                snapshot: WidgetSnapshot(
                    updatedAt: .now,
                    tasks: [],
                    habits: [],
                    waterTodayML: 0,
                    waterGoalML: 2_000,
                    filledWaterGlasses: 0,
                    waterGlassCount: 8,
                    habitsDone: 0,
                    habitsTotal: 0,
                    openTaskCount: 0,
                    dayStreak: 0,
                    stepsToday: 8_432,
                    stepGoal: 10_000,
                    workoutDoneToday: true,
                    workoutMinutesToday: 42,
                    wellnessScore: 78
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
