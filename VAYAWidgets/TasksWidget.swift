import WidgetKit
import SwiftUI

struct VAYATasksWidget: Widget {
    let kind = "VAYATasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VAYAWidgetProvider()) { entry in
            VAYATasksWidgetView(entry: entry)
                .widgetURL(WidgetSharedConstants.tasksTabURL)
                .vayaWidgetBackground()
        }
        .configurationDisplayName("Tasks")
        .description("See today's open tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VAYATasksWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: VAYAWidgetEntry

    var body: some View {
        tasksContent
    }

    @ViewBuilder
    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 8 : 10) {
            if entry.snapshot.tasks.isEmpty {
                VAYAWidgetCardHeader(
                    title: "Tasks",
                    systemImage: "checklist",
                    value: "0",
                    subtitle: "open tasks"
                )
                Spacer(minLength: 0)
                Text("Nothing due")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textPrimary)
                Text("Tap to add a task")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textSecondary)
            } else {
                VAYAWidgetCardHeader(
                    title: "Tasks",
                    systemImage: "checklist",
                    value: "\(entry.snapshot.openTaskCount)",
                    subtitle: "open tasks"
                )

                VStack(spacing: 5) {
                    ForEach(entry.snapshot.tasks.prefix(widgetFamily.vayaMaxListRows)) { task in
                        VAYAWidgetStatusRow(
                            title: task.title,
                            isDone: task.isComplete,
                            style: .task,
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
    VAYATasksWidget()
} timeline: {
    VAYAWidgetEntry(date: .now, snapshot: .preview)
}
