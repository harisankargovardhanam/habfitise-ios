import SwiftUI
import SwiftData

struct AddHabitSheet: View {
    @Environment(ThemeManager.self) private var theme
    let userId: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @FocusState private var isNameFocused: Bool

    @State private var name = ""
    @State private var frequencyMode: HabitFrequencyMode = .daily
    @State private var selectedWeekdays: Set<WeekdaySelection> = []
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? .now
    @State private var selectedColor = HabitColorOption.palette[0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HabfitiseSpacing.xxl) {
                    nameField
                    frequencySection
                    timeSection
                    colorSection
                }
                .padding(HabfitiseSpacing.xxl)
                .padding(.bottom, HabfitiseSpacing.md)
            }
            .scrollIndicators(.hidden)
            .background(theme.colors.cardBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(theme.colors.cardBorder)

                    saveButton
                        .padding(.horizontal, HabfitiseSpacing.xxl)
                        .padding(.top, HabfitiseSpacing.lg)
                        .padding(.bottom, HabfitiseSpacing.lg)
                }
                .background(theme.colors.cardBackground.ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isNameFocused = true
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Name")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            TextField("e.g. Morning stretch", text: $name)
                .focused($isNameFocused)
                .font(HabfitiseTypography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .padding(HabfitiseSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HabfitiseRadius.md)
                        .fill(theme.colors.chipBackground)
                )
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Frequency")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            Picker("Frequency", selection: $frequencyMode) {
                ForEach(HabitFrequencyMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if frequencyMode == .specificDays {
                weekdayPicker
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            ForEach(WeekdaySelection.allCases) { day in
                let isSelected = selectedWeekdays.contains(day)
                Button {
                    if isSelected {
                        selectedWeekdays.remove(day)
                    } else {
                        selectedWeekdays.insert(day)
                    }
                } label: {
                    Text(day.shortLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? theme.colors.textOnBackground : theme.colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? theme.colors.accentGreen : theme.colors.chipBackground)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
            Text("Reminder")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            DatePicker(
                "Time",
                selection: $reminderTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(theme.colors.accentGreen)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Colour")
                .font(HabfitiseTypography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            HStack(spacing: HabfitiseSpacing.lg) {
                ForEach(HabitColorOption.palette) { option in
                    Button {
                        selectedColor = option
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if selectedColor == option {
                                    Circle()
                                        .strokeBorder(Color.black.opacity(0.25), lineWidth: 2)
                                        .padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveButton: some View {
        HabfitisePrimaryButton(title: "Save Habit") {
            saveHabit()
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func saveHabit() {
        let frequency: String
        if frequencyMode == .daily {
            frequency = "daily"
        } else {
            let keys = WeekdaySelection.allCases
                .filter { selectedWeekdays.contains($0) }
                .map(\.storageKey)
            frequency = keys.isEmpty ? "daily" : keys.joined(separator: ",")
        }

        let habit = Habit(
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            reminderTime: reminderTime,
            colorHex: selectedColor.hex,
            synced: false
        )
        modelContext.insert(habit)
        try? modelContext.save()

        Task {
            await NotificationService.shared.scheduleHabitReminder(habit: habit, context: modelContext)
        }

        onSave()
        dismiss()
    }
}

#if DEBUG
struct AddHabitSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddHabitSheet(userId: "preview", onSave: {})
            .modelContainer(try! SwiftDataStack.makeContainer(inMemory: true))
            .environment(ThemeManager())
    }
}
#endif
