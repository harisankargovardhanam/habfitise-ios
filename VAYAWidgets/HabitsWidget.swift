import WidgetKit
import SwiftUI

struct VAYAHabitsWidget: Widget {
    let kind = "VAYAHabitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VAYAWidgetProvider()) { entry in
            VAYAHabitsWidgetView(entry: entry)
                .widgetURL(WidgetSharedConstants.habitsTabURL)
                .vayaWidgetBackground()
        }
        .configurationDisplayName("Habits")
        .description("Track today's habit progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VAYAHabitsWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: VAYAWidgetEntry

    var body: some View {
        habitsContent
    }

    @ViewBuilder
    private var habitsContent: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 8 : 10) {
            if entry.snapshot.habits.isEmpty {
                VAYAWidgetCardHeader(
                    title: "Habits",
                    systemImage: "leaf.fill",
                    value: "0",
                    subtitle: "completed"
                )
                Spacer(minLength: 0)
                Text("No habits yet")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textSecondary)
            } else {
                VAYAWidgetCardHeader(
                    title: "Habits",
                    systemImage: "leaf.fill",
                    value: "\(entry.snapshot.habitsDone)/\(entry.snapshot.habitsTotal)",
                    subtitle: "completed today"
                )

                VStack(spacing: 5) {
                    ForEach(entry.snapshot.habits.prefix(widgetFamily.vayaMaxListRows)) { habit in
                        VAYAWidgetStatusRow(
                            title: habit.name,
                            isDone: habit.isCompleted,
                            style: .habit,
                            compact: widgetFamily.vayaUsesCompactRows
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(widgetFamily.vayaContentPadding)
    }
}

#Preview(as: .systemSmall) {
    VAYAHabitsWidget()
} timeline: {
    VAYAWidgetEntry(date: .now, snapshot: .preview)
}
