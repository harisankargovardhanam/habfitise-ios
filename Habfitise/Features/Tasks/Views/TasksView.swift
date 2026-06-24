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
    @Environment(SyncService.self) private var syncService
    let userId: String
    var showsBackButton = false

    @Environment(\.modelContext) private var modelContext
    @Environment(TabBarState.self) private var tabBarState
    @State private var viewModel = TasksViewModel()

    @Query private var tasks: [TaskRecord]
    @Query private var habits: [Habit]

    init(userId: String, showsBackButton: Bool = false) {
        let normalizedUserId = userId.lowercased()
        self.userId = normalizedUserId
        self.showsBackButton = showsBackButton

        _tasks = Query(
            filter: #Predicate<TaskRecord> { task in
                task.userId == normalizedUserId
            },
            sort: [SortDescriptor(\.dueDate)]
        )

        _habits = Query(
            filter: #Predicate<Habit> { habit in
                habit.userId == normalizedUserId && habit.isActive
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
                        pushToCloud()
                    }
                }
            }
            .alert("Delete task?", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    HabfitiseHaptics.destructive()
                    if let task = viewModel.taskPendingDelete {
                        viewModel.deleteTask(task, context: modelContext)
                        pushToCloud()
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                tasksHeader
                    .habfitiseStaggeredAppear(index: 0)

                if tasks.isEmpty {
                    emptyStateContent
                        .habfitiseStaggeredAppear(index: 1)
                } else {
                    taskListContent
                        .habfitiseStaggeredAppear(index: 1)
                }
            }
            .padding(.bottom, TabBarLayout.tabBarScrollInset)
            .reportScrollOffsetToTabBar()
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .cloudRefreshable(scope: .tasks, perform: syncViewModel)
    }

    private var tasksHeader: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            if !showsBackButton {
                HabfitiseTabPageHeader(title: "Tasks") {
                    HabitsAddButton {
                        viewModel.showAddTask = true
                    }
                }
            }

            TasksHeaderChipRow(
                todayCount: viewModel.todayCount,
                upcomingCount: viewModel.upcomingCount
            )
            .padding(.horizontal, HabfitiseSpacing.lg)
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: HabfitiseSpacing.lg) {
            HabfitiseEmptyState(
                icon: "checklist",
                title: "No tasks yet",
                subtitle: "Capture what you need to do today and stay on track."
            )

            Button {
                viewModel.showAddTask = true
            } label: {
                Text("Add your first task")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textOnBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.colors.accentGreen)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, HabfitiseSpacing.xxxl)
        }
        .padding(.horizontal, HabfitiseSpacing.lg)
        .padding(.top, HabfitiseSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    private var taskListContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(TaskSection.allCases) { section in
                let sectionTasks = viewModel.openTasks(for: section)
                if !sectionTasks.isEmpty {
                    taskSectionLabel(section.title, isFirst: section == .today)

                    ForEach(Array(sectionTasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            showsDueChip: section != .today,
                            onToggle: {
                                viewModel.completeTask(task, context: modelContext)
                                pushToCloud()
                            },
                            onDelete: {
                                viewModel.requestDelete(task)
                            },
                            onReschedule: {
                                viewModel.requestReschedule(task)
                            }
                        )

                        if index < sectionTasks.count - 1 {
                            taskRowDivider
                        }
                    }
                }
            }

            if !viewModel.completedTasks.isEmpty {
                let noOpenTasks = TaskSection.allCases.allSatisfy {
                    viewModel.openTasks(for: $0).isEmpty
                }
                taskSectionLabel("Done", isFirst: noOpenTasks)

                ForEach(Array(viewModel.completedTasks.enumerated()), id: \.element.id) { index, task in
                    TaskRow(
                        task: task,
                        showsDueChip: false,
                        onToggle: {},
                        onDelete: {
                            viewModel.requestDelete(task)
                        },
                        onReschedule: {
                            viewModel.requestReschedule(task)
                        }
                    )

                    if index < viewModel.completedTasks.count - 1 {
                        taskRowDivider
                    }
                }
            }
        }
    }

    private var taskRowDivider: some View {
        Rectangle()
            .fill(theme.colors.trackBackground)
            .frame(height: 1)
            .padding(.leading, HabfitiseSpacing.lg + 28 + HabfitiseSpacing.md)
    }

    private func taskSectionLabel(_ title: String, isFirst: Bool) -> some View {
        Text(title.uppercased())
            .font(HabfitiseTypography.sectionLabel)
            .tracking(1.2)
            .foregroundStyle(theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HabfitiseSpacing.lg)
            .padding(.top, isFirst ? 0 : HabfitiseSpacing.lg)
            .padding(.bottom, HabfitiseSpacing.xs)
    }

    private func syncViewModel() {
        viewModel.bind(tasks: tasks)
        WidgetDataPublisher.refresh(context: modelContext, userId: userId)
    }

    private func pushToCloud() {
        syncService.schedulePush(modelContext: modelContext, userId: userId)
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
