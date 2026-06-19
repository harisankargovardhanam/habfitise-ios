import SwiftUI
import SwiftData

private enum SwiftDataQueryDateBounds {
    static func dayStart() -> Date {
        Calendar.current.startOfDay(for: .now)
    }

    static func dayEnd() -> Date {
        let start = dayStart()
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }
}

// MARK: - @Query in Views (live SwiftData updates)
//
// `@Query` is a SwiftUI property wrapper — use it in Views, not @Observable ViewModels.
// ViewModels receive fetched data or a ModelContext for writes.
// Pattern: View owns @Query → passes results into ViewModel methods.

/// Live habits list — re-renders when SwiftData store changes.
struct HabitsLiveQueryView: View {
    let userId: String
    @Environment(ThemeManager.self) private var theme
    @State private var viewModel = HabitsViewModel()

    @Query private var habits: [Habit]

    init(userId: String) {
        self.userId = userId
        _habits = Query(
            filter: #Predicate<Habit> { habit in
                habit.userId == userId && habit.isActive
            },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        List(habits) { habit in
            HStack {
                Text(habit.name)
                    .font(HabfitiseTypography.body)
                Spacer()
                Text("\(viewModel.streak(for: habit.id))")
                    .font(HabfitiseTypography.numericCaption)
                    .foregroundStyle(theme.colors.accentGreen)
            }
        }
        .onAppear {
            viewModel.bind(habits: habits)
        }
        .onChange(of: habits) { _, updated in
            viewModel.bind(habits: updated)
        }
    }
}

/// Live water total for today — numeric display uses monospaced typography token.
struct WaterLiveQueryView: View {
    let userId: String
    @Environment(ThemeManager.self) private var theme

    @Query private var todayLogs: [WaterLog]

    init(userId: String) {
        self.userId = userId
        let start = SwiftDataQueryDateBounds.dayStart()
        let end = SwiftDataQueryDateBounds.dayEnd()
        _todayLogs = Query(
            filter: #Predicate<WaterLog> { log in
                log.userId == userId
                    && log.loggedAt >= start
                    && log.loggedAt < end
            },
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
    }

    private var totalMl: Int {
        todayLogs.reduce(0) { $0 + $1.amountMl }
    }

    var body: some View {
        HStack {
            Text("\(totalMl) ml")
                .font(HabfitiseTypography.numericTitle2)
                .foregroundStyle(theme.colors.waterBlue)
            Spacer()
            WaterCupIcon(fillLevel: min(Double(totalMl) / 2500.0, 1.0))
        }
    }
}

/// Live tasks due today.
struct TasksLiveQueryView: View {
    let userId: String

    @Query private var tasks: [TaskRecord]

    init(userId: String) {
        self.userId = userId
        let start = SwiftDataQueryDateBounds.dayStart()
        let end = SwiftDataQueryDateBounds.dayEnd()
        _tasks = Query(
            filter: #Predicate<TaskRecord> { task in
                task.userId == userId
                    && task.isComplete == false
                    && task.dueDate != nil
                    && task.dueDate! >= start
                    && task.dueDate! < end
            },
            sort: [SortDescriptor(\.dueDate)]
        )
    }

    var body: some View {
        ForEach(tasks) { task in
            Text(task.title)
                .font(HabfitiseTypography.body)
        }
    }
}

// MARK: - ViewModel pattern (ModelContext for writes, stack for reads)

#if DEBUG
struct SwiftDataQueryExamples_Previews: PreviewProvider {
    static var previews: some View {
        let stack = SwiftDataStack.makePreviewStack()
        let userId = "preview-user"

        stack.mainContext.insert(
            Habit(userId: userId, name: "Morning stretch", colorHex: "22C55E")
        )
        stack.mainContext.insert(
            WaterLog(userId: userId, amountMl: 500, loggedAt: .now)
        )
        try? stack.mainContext.save()

        return Group {
            HabitsLiveQueryView(userId: userId)
                .previewDisplayName("Habits @Query")

            WaterLiveQueryView(userId: userId)
                .previewDisplayName("Water @Query")
        }
        .modelContainer(stack.container)
    }
}
#endif
