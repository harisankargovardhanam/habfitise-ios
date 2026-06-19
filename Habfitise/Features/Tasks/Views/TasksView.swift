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
                    .tint(theme.colors.textOnBackground)
                    .habfitiseGreenBackground()
            }
        }
    }
}

struct TasksContentView: View {
    @Environment(ThemeManager.self) private var theme
    let userId: String
    var showsBackButton = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                ZStack(alignment: .top) {
                    theme.colors.headerBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        greenArea
                            .frame(height: geometry.size.height * 0.28)

                        Spacer(minLength: 0)
                    }

                    VStack {
                        Spacer(minLength: 0)
                        whiteCard
                            .frame(height: geometry.size.height * 0.76)
                    }
                }

                TasksFAB(pulse: viewModel.totalOpenTasks > 0) {
                    viewModel.showAddTask = true
                }
                .padding(.trailing, HabfitiseSpacing.xxl)
                .padding(.bottom, HabfitiseSpacing.xxxl + 72)
            }
        }
        .habfitiseTabScreen()
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

    // MARK: - Green Area

    private var greenArea: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(alignment: .center) {
                if showsBackButton {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.colors.textOnBackground)
                    }
                }

                Text("Tasks")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textOnBackground)

                Spacer()
            }

            TasksHeaderChipRow(
                todayCount: viewModel.todayCount,
                upcomingCount: viewModel.upcomingCount
            )
        }
        .padding(.horizontal, HabfitiseSpacing.lg)
        .padding(.top, HabfitiseSpacing.sm)
    }

    // MARK: - White Card

    private var whiteCard: some View {
        Group {
            if tasks.isEmpty {
                ScrollView {
                    VStack(spacing: HabfitiseSpacing.lg) {
                        HabfitiseSectionLabel(text: "Today")
                        Text("No tasks yet")
                            .font(HabfitiseTypography.subheadline)
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, HabfitiseSpacing.lg)
                    }
                    .padding(.top, HabfitiseSpacing.xxl)
                }
                .habfitiseCard()
            } else {
                taskList
            }
        }
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
        .reportScrollOffsetToTabBar()
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .habfitiseCard()
    }

    private func syncViewModel() {
        viewModel.bind(tasks: tasks)
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
