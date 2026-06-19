import SwiftUI

// MARK: - Exercise row (setup)

struct ExerciseRowBuilder: View {
    @Environment(ThemeManager.self) private var theme

    let exercise: BuilderDraftExercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.colors.textPrimary)
                        Text(exercise.category.rawValue.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.colors.accentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(theme.colors.chipDone))
                    }
                    Text(exercise.setsPreview)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colors.chipBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    let workoutType: WorkoutType
    let onSelectCatalog: (CatalogExercise) -> Void
    let onSelectCardio: (CardioOption) -> Void
    let onAddCustom: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var customName = ""

    private let categories: [ExerciseCategory?] = [nil, .chest, .back, .legs, .shoulders, .arms, .core]

    var body: some View {
        NavigationStack {
            Group {
                if workoutType == .cardio {
                    cardioGrid
                } else {
                    strengthList
                }
            }
            .background(theme.colors.cardBackground.ignoresSafeArea())
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises...")
        }
    }

    private var strengthList: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        let title = category?.rawValue.capitalized ?? "All"
                        let selected = selectedCategory == category
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? theme.colors.textOnBackground : theme.colors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(selected ? theme.colors.accentGreen : theme.colors.chipBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            List {
                ForEach(WorkoutExerciseCatalog.filtered(category: selectedCategory, query: searchText, workoutType: workoutType)) { item in
                    Button {
                        onSelectCatalog(item)
                        dismiss()
                    } label: {
                        HStack {
                            Text(item.name)
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Text(item.category.rawValue.capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.colors.accentGreen)
                        }
                    }
                    .listRowBackground(theme.colors.fieldBackground)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSelectCatalog(item)
                            dismiss()
                        }
                    )
                }

                Section {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundStyle(theme.colors.accentGreen)
                        TextField("Custom exercise name", text: $customName)
                            .foregroundStyle(theme.colors.textPrimary)
                        Button("Add") {
                            onAddCustom(customName)
                            customName = ""
                            dismiss()
                        }
                        .foregroundStyle(theme.colors.accentGreen)
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var cardioGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WorkoutExerciseCatalog.cardio) { option in
                    Button {
                        onSelectCardio(option)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Text(option.emoji)
                                .font(.system(size: 28))
                            Text(option.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.colors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.colors.fieldBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            HStack {
                TextField("Custom activity", text: $customName)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.colors.fieldBackground))
                Button("Add") {
                    onAddCustom(customName)
                    dismiss()
                }
                .foregroundStyle(theme.colors.accentGreen)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Set row (active)

struct BuilderSetRow: View {
    @Environment(ThemeManager.self) private var theme

    let exercise: BuilderDraftExercise
    let set: BuilderSetState
    let isFlashing: Bool
    let isFirstSet: Bool
    let volumeHint: VolumeProgressHint?
    let oneRMEstimate: Double?
    let onOneRMInfo: () -> Void
    let onAdjustReps: (Int) -> Void
    let onAdjustWeight: (Double) -> Void
    let onAdjustDuration: (Int) -> Void
    let onAdjustDistance: (Double) -> Void
    let onComplete: () -> Void
    let onLongPress: () -> Void

    init(
        exercise: BuilderDraftExercise,
        set: BuilderSetState,
        isFlashing: Bool,
        isFirstSet: Bool = false,
        volumeHint: VolumeProgressHint? = nil,
        oneRMEstimate: Double? = nil,
        onOneRMInfo: @escaping () -> Void = {},
        onAdjustReps: @escaping (Int) -> Void,
        onAdjustWeight: @escaping (Double) -> Void,
        onAdjustDuration: @escaping (Int) -> Void,
        onAdjustDistance: @escaping (Double) -> Void,
        onComplete: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.exercise = exercise
        self.set = set
        self.isFlashing = isFlashing
        self.isFirstSet = isFirstSet
        self.volumeHint = volumeHint
        self.oneRMEstimate = oneRMEstimate
        self.onOneRMInfo = onOneRMInfo
        self.onAdjustReps = onAdjustReps
        self.onAdjustWeight = onAdjustWeight
        self.onAdjustDuration = onAdjustDuration
        self.onAdjustDistance = onAdjustDistance
        self.onComplete = onComplete
        self.onLongPress = onLongPress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isFirstSet, let volumeHint {
                HStack {
                    Spacer().frame(width: 28)
                    VolumeProgressChip(hint: volumeHint)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
            Text(set.isWarmup ? "W" : "\(set.setNumber)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(set.isWarmup ? Color(hex: "#FF6B35") : theme.colors.textSecondary)
                .frame(width: 28)

            Text(set.previousSummary)
                .font(.system(size: 12, weight: .medium))
                .italic()
                .foregroundStyle(theme.colors.textSecondary)
                .frame(width: 56, alignment: .leading)

            if exercise.type == .cardio || exercise.type == .timed {
                cardioControls
            } else {
                strengthControls
            }

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(set.isCompleted ? theme.colors.accentGreen : theme.colors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(set.isCompleted)

            if set.isPersonalRecord {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(hex: "#F59E0B"))
                    Text("PR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
            }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFlashing ? theme.colors.accentGreen.opacity(0.25) : theme.colors.chipBackground)
            )
            .onLongPressGesture(minimumDuration: 0.4) {
                onLongPress()
            }

            if let oneRMEstimate, set.isCompleted {
                OneRMInlineBadge(estimateKg: oneRMEstimate, onInfoTap: onOneRMInfo)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private var strengthControls: some View {
        stepperColumn(title: "REPS", value: "\(set.reps ?? 0)") {
            onAdjustReps(-1)
        } increment: {
            onAdjustReps(1)
        }

        stepperColumn(
            title: exercise.type == .bodyweight ? "BW" : "KG",
            value: exercise.type == .bodyweight ? "BW" : String(format: "%.1f", set.weightKg ?? 0)
        ) {
            onAdjustWeight(-0.5)
        } increment: {
            onAdjustWeight(0.5)
        }
    }

    @ViewBuilder
    private var cardioControls: some View {
        stepperColumn(title: "TIME", value: formatDuration(set.durationSeconds ?? 0)) {
            onAdjustDuration(-15)
        } increment: {
            onAdjustDuration(15)
        }

        stepperColumn(title: "KM", value: String(format: "%.1f", set.distanceKm ?? 0)) {
            onAdjustDistance(-0.1)
        } increment: {
            onAdjustDistance(0.1)
        }
    }

    private func stepperColumn(title: String, value: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary)
            HStack(spacing: 4) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(theme.colors.textTertiary)
                }
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(minWidth: 44)
                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Rest timer

struct BuilderRestTimerBar: View {
    @Environment(ThemeManager.self) private var theme

    let countdown: String
    let progress: Double
    let isWarning: Bool
    let onSkip: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colors.trackBackground)
                    Capsule()
                        .fill(isWarning ? Color(hex: "#F59E0B") : theme.colors.accentGreen)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Button(action: onEdit) {
                    Text(countdown)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Skip", action: onSkip)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.accentGreen)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }
}

// MARK: - Cardio live timer

struct CardioLiveTimerView: View {
    @Environment(ThemeManager.self) private var theme

    let seconds: Int
    let isRunning: Bool
    let onToggle: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(format(seconds))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(theme.colors.accentGreen)
                .monospacedDigit()

            HStack(spacing: 16) {
                Button(isRunning ? "Pause" : "Resume", action: onToggle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.colors.chipBackground))

                Button("Stop & log", action: onStop)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.textOnBackground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.colors.accentGreen))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

// MARK: - Rest duration editor

struct RestDurationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    @State var seconds: Int
    let onSave: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(seconds)s")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(theme.colors.textPrimary)
                Stepper("Rest duration", value: $seconds, in: 0...300, step: 15)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 32)
            .background(theme.colors.cardBackground.ignoresSafeArea())
            .navigationTitle("Rest Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(seconds)
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
