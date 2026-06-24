import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(SyncService.self) private var syncService
    let userId: String
    let habits: [Habit]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @FocusState private var isTitleFocused: Bool

    @State private var title = ""
    @State private var quickDate: TaskQuickDate = .today
    @State private var pickedDate = Date.now
    @State private var recurrence = TaskRecurrence.none
    @State private var linkedHabitId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                    titleField
                    quickDateSection
                    recurrenceSection
                    habitLinkSection
                    saveButton
                }
                .padding(HabfitiseSpacing.xxl)
            }
            .background(theme.colors.cardBackground)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            isTitleFocused = true
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Title")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            TextField("What needs doing?", text: $title)
                .focused($isTitleFocused)
                .font(HabfitiseTypography.body)
                .padding(HabfitiseSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                        .fill(theme.colors.chipBackground)
                )
        }
    }

    private var quickDateSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Due date")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            HStack(spacing: HabfitiseSpacing.sm) {
                ForEach(TaskQuickDate.allCases) { option in
                    Button {
                        quickDate = option
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                quickDate == option ? theme.colors.textOnBackground : theme.colors.textPrimary
                            )
                            .padding(.horizontal, HabfitiseSpacing.md)
                            .padding(.vertical, HabfitiseSpacing.sm)
                            .background {
                                Capsule().fill(
                                    quickDate == option
                                        ? theme.colors.accentGreen
                                        : theme.colors.chipBackground
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if quickDate == .pickDate {
                DatePicker(
                    "Pick date",
                    selection: $pickedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Recurrence")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            Picker("Recurrence", selection: $recurrence) {
                ForEach(TaskRecurrence.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(HabfitiseSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                    .fill(theme.colors.chipBackground)
            )
        }
    }

    private var habitLinkSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Link to habit")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            Menu {
                Button("None") {
                    linkedHabitId = nil
                }
                ForEach(habits) { habit in
                    Button(habit.name) {
                        linkedHabitId = habit.id
                    }
                }
            } label: {
                HStack {
                    Text(linkedHabitLabel)
                        .font(HabfitiseTypography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.textTertiary)
                }
                .padding(HabfitiseSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                        .fill(theme.colors.chipBackground)
                )
            }
        }
    }

    private var saveButton: some View {
        HabfitisePrimaryButton(title: "Save") {
            saveTask()
        }
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var linkedHabitLabel: String {
        guard let linkedHabitId,
              let habit = habits.first(where: { $0.id == linkedHabitId }) else {
            return "None"
        }
        return habit.name
    }

    private func saveTask() {
        let dueDate: Date?
        switch quickDate {
        case .today:
            dueDate = Calendar.current.startOfDay(for: .now)
        case .tomorrow:
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
        case .pickDate:
            dueDate = pickedDate
        }

        let normalizedUserId = userId.lowercased()
        let task = TaskRecord(
            userId: normalizedUserId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            recurrence: recurrence == .none ? nil : recurrence.rawValue,
            linkedHabitId: linkedHabitId,
            synced: false
        )
        modelContext.insert(task)
        try? modelContext.save()

        syncService.schedulePush(modelContext: modelContext, userId: normalizedUserId)
        WidgetDataPublisher.refresh(context: modelContext, userId: normalizedUserId)

        onSave()
        dismiss()
    }
}

struct RescheduleTaskSheet: View {
    @Environment(ThemeManager.self) private var theme
    let task: TaskRecord
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(task: TaskRecord, onSave: @escaping (Date) -> Void) {
        self.task = task
        self.onSave = onSave
        _selectedDate = State(initialValue: task.dueDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: HabfitiseSpacing.xxl) {
                Text(task.title)
                    .font(HabfitiseTypography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DatePicker(
                    "New due date",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)

                HabfitisePrimaryButton(title: "Save") {
                    onSave(selectedDate)
                    dismiss()
                }
            }
            .padding(HabfitiseSpacing.xxl)
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
struct AddTaskSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskSheet(userId: "preview", habits: [], onSave: {})
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
            .environment(ThemeManager())
    }
}
#endif
