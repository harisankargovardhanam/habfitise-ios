import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let userId = appState.authenticatedUserId {
                TasksContentView(userId: userId)
            } else {
                ProgressView()
                    .tint(theme.colors.accentGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.background.ignoresSafeArea())
            }
        }
    }
}

struct TasksContentView: View {
    @Environment(ThemeManager.self) private var theme
    let userId: String
    var showsBackButton = false

    @Environment(\.modelContext) private var modelContext
    @Environment(TabBarState.self) private var tabBarState
    @State private var viewModel = TasksViewModel()

    @Query private var tasks: [TaskRecord]
    @Query private var habits: [Habit]

    init(userId: String, showsBackButton: Bool = false) {
        self.userId = userId
        self.showsBackButton = showsBackButton

        _tasks = Query(
            filter: #Predicate<TaskRecord> { task in
                task.userId == userId
            },
            sort: [SortDescriptor(\.dueDate)]
        )

        _habits = Query(
            filter: #Predicate<Habit> { habit in
                habit.userId == userId && habit.isActive
            },
            sort: [SortDescriptor(\.name)]
        )
    }

    var body: some View {
        tasksScreenContent
            .background(theme.colors.background.ignoresSafeArea())
            .modifier(TasksScreenChromeModifier(
                showsBackButton: showsBackButton,
                onAdd: { viewModel.showAddTask = true }
            ))
            .onAppear {
                tabBarState.resetScrollState()
                syncViewModel()
            }
            .onChange(of: tasks.map(\.id)) { _, _ in syncViewModel() }
            .onChange(of: tasks.map(\.isComplete)) { _, _ in syncViewModel() }
            .sheet(isPresented: $viewModel.showAddTask) {
                AddTaskSheet(userId: userId, habits: habits) {
                    syncViewModel()
                }
            }
            .sheet(isPresented: $viewModel.showRescheduleSheet) {
                if let task = viewModel.taskPendingReschedule {
                    RescheduleTaskSheet(task: task) { date in
                        viewModel.rescheduleTask(task, to: date, context: modelContext)
                    }
                }
            }
            .alert("Delete task?", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    HabfitiseHaptics.destructive()
                    if let task = viewModel.taskPendingDelete {
                        viewModel.deleteTask(task, context: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.taskPendingDelete = nil
                }
            } message: {
                if let task = viewModel.taskPendingDelete {
                    Text("“\(task.title)” will be removed permanently.")
                }
            }
    }

    private var tasksScreenContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                tasksHeader
                    .habfitiseStaggeredAppear(index: 0)

                if tasks.isEmpty {
                    emptyState
                        .habfitiseStaggeredAppear(index: 1)
                } else {
                    taskList
                        .habfitiseStaggeredAppear(index: 1)
                }
            }

            TasksFAB(pulse: viewModel.totalOpenTasks > 0) {
                viewModel.showAddTask = true
            }
            .padding(.trailing, HabfitiseSpacing.lg)
            .padding(.bottom, TabBarLayout.floatingClearance)
        }
    }

    private var tasksHeader: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            if !showsBackButton {
                HabfitiseTabPageHeader(title: "Tasks")
            }

            TasksHeaderChipRow(
                todayCount: viewModel.todayCount,
                upcomingCount: viewModel.upcomingCount
            )
            .padding(.horizontal, HabfitiseSpacing.lg)
        }
        .padding(.bottom, HabfitiseSpacing.md)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                HabfitiseSectionLabel(text: "Today")
                Text("No tasks yet")
                    .font(HabfitiseTypography.subheadline)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(.horizontal, HabfitiseSpacing.lg)
            .padding(.top, HabfitiseSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .reportScrollOffsetToTabBar()
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
    }

    private var taskList: some View {
        List {
            ForEach(TaskSection.allCases) { section in
                let sectionTasks = viewModel.tasks(for: section)
                if !sectionTasks.isEmpty {
                    Section {
                        ForEach(Array(sectionTasks.enumerated()), id: \.element.id) { index, task in
                            TaskRow(
                                task: task,
                                onToggle: {
                                    viewModel.completeTask(task, context: modelContext)
                                },
                                onDelete: {
                                    viewModel.requestDelete(task)
                                },
                                onReschedule: {
                                    viewModel.requestReschedule(task)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(index == sectionTasks.count - 1 ? .hidden : .visible, edges: .bottom)
                            .listRowSeparatorTint(theme.colors.trackBackground)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        HabfitiseSectionLabel(text: section.title)
                            .textCase(nil)
                            .padding(.top, section == .today ? HabfitiseSpacing.sm : HabfitiseSpacing.lg)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .reportScrollOffsetToTabBar()
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
    }

    private func syncViewModel() {
        viewModel.bind(tasks: tasks)
    }
}

private struct TasksScreenChromeModifier: ViewModifier {
    let showsBackButton: Bool
    let onAdd: () -> Void

    func body(content: Content) -> some View {
        if showsBackButton {
            content
                .habfitisePushedScreen(title: "Tasks") {
                    HabitsAddButton(action: onAdd)
                }
        } else {
            content
                .habfitiseTabScreen(immersiveHeader: true)
        }
    }
}

#if DEBUG
struct TasksView_Previews: PreviewProvider {
    static var previews: some View {
        TasksContentView(userId: "preview-user")
            .environment(AppState())
            .environment(TabBarState())
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
            .environment(ThemeManager())
    }
}
#endif
