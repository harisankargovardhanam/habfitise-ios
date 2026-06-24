import SwiftUI
import WidgetKit

enum VAYAWidgetPalette {
    static let background = Color(red: 0.08, green: 0.10, blue: 0.09)
    static let fieldBackground = Color(red: 0.14, green: 0.16, blue: 0.15)
    static let fieldBackgroundDone = Color(red: 0.14, green: 0.16, blue: 0.15).opacity(0.55)
    static let accent = Color(red: 0.45, green: 0.85, blue: 0.55)
    static let waterBlue = Color(red: 0.35, green: 0.72, blue: 0.95)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.42)
    static let chipBackground = Color.white.opacity(0.08)
    static let trackBackground = Color.white.opacity(0.1)
}

struct VAYAWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct VAYAWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VAYAWidgetEntry {
        VAYAWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (VAYAWidgetEntry) -> Void) {
        completion(VAYAWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VAYAWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        let entry = VAYAWidgetEntry(date: .now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct VAYAWidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .widget) {
                VAYAWidgetPalette.background
            }
    }
}

extension View {
    func vayaWidgetBackground() -> some View {
        modifier(VAYAWidgetBackground())
    }
}

struct VAYAWidgetCardHeader: View {
    let title: String
    let systemImage: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VAYAWidgetPalette.accent)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textPrimary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textSecondary)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct VAYAWidgetStatusRow: View {
    enum Style {
        case habit
        case task

        var pendingLabel: String {
            switch self {
            case .habit: "Not yet"
            case .task: "Open"
            }
        }
    }

    let title: String
    let isDone: Bool
    let style: Style
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Text(title)
                .font(.system(size: compact ? 12 : 13, weight: isDone ? .regular : .semibold, design: .rounded))
                .foregroundStyle(isDone ? VAYAWidgetPalette.textSecondary : VAYAWidgetPalette.textPrimary)
                .strikethrough(isDone, color: VAYAWidgetPalette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            statusBadge
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDone ? VAYAWidgetPalette.fieldBackgroundDone : VAYAWidgetPalette.fieldBackground)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if compact && !isDone {
            Image(systemName: "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VAYAWidgetPalette.textSecondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(VAYAWidgetPalette.chipBackground))
        } else if compact && isDone {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VAYAWidgetPalette.accent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(VAYAWidgetPalette.accent.opacity(0.14)))
        } else {
            HStack(spacing: 3) {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(isDone ? "Done" : style.pendingLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isDone ? VAYAWidgetPalette.accent : VAYAWidgetPalette.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    isDone
                        ? VAYAWidgetPalette.accent.opacity(0.14)
                        : VAYAWidgetPalette.chipBackground
                )
            )
        }
    }
}

extension WidgetFamily {
    var vayaMaxListRows: Int {
        switch self {
        case .systemSmall: 2
        default: 4
        }
    }

    var vayaUsesCompactRows: Bool {
        self == .systemSmall
    }

    var vayaContentPadding: CGFloat {
        self == .systemSmall ? 12 : 14
    }
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        updatedAt: .now,
        tasks: [
            WidgetTaskItem(id: "1", title: "Morning stretch", isComplete: false),
            WidgetTaskItem(id: "2", title: "Plan meals", isComplete: false)
        ],
        habits: [
            WidgetHabitItem(id: "1", name: "Meditate", isCompleted: true),
            WidgetHabitItem(id: "2", name: "Read", isCompleted: false)
        ],
        waterTodayML: 1_200,
        waterGoalML: 2_500,
        filledWaterGlasses: 4,
        waterGlassCount: 8,
        habitsDone: 1,
        habitsTotal: 2,
        openTaskCount: 2,
        dayStreak: 5,
        stepsToday: 6_540,
        stepGoal: 10_000,
        workoutDoneToday: true,
        workoutMinutesToday: 35,
        wellnessScore: 72
    )
}
