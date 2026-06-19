import SwiftUI

// MARK: - ExerciseDetailEditor (W4)

struct ExerciseDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var theme
    @Environment(AppState.self) private var appState

    @State var exercise: BuilderDraftExercise
    let onSave: (BuilderDraftExercise) -> Void
    @State private var showOneRMDetail = false

    private let sheetBackground = Color(hex: "#111111")
    private let fieldBackground = Color(hex: "#2A2A2A")
    private let mutedText = Color(hex: "#9CA3AF")
    private let accentGreen = Color(hex: "#22C55E")

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if exercise.type == .cardio {
                        cardioContent
                    } else if exercise.type == .timed {
                        timedContent
                    } else {
                        strengthContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(sheetBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showOneRMDetail) {
            OneRMDetailSheet(
                exerciseName: exercise.name,
                history: WorkoutAnalytics.oneRMHistory(
                    exerciseName: exercise.name,
                    userId: appState.authenticatedUserId ?? "",
                    context: modelContext
                )
            )
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text(exercise.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 12)
            Button("Done") {
                onSave(exercise)
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(accentGreen)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Strength / bodyweight

    @ViewBuilder
    private var strengthContent: some View {
        EditorStepperRow(
            title: "DEFAULT SETS",
            value: "\(exercise.defaultSets)",
            onDecrement: { exercise.defaultSets = max(1, exercise.defaultSets - 1) },
            onIncrement: { exercise.defaultSets = min(10, exercise.defaultSets + 1) }
        )

        EditorStepperRow(
            title: "DEFAULT REPS",
            value: "\(exercise.defaultReps)",
            onDecrement: { exercise.defaultReps = max(1, exercise.defaultReps - 1) },
            onIncrement: { exercise.defaultReps = min(50, exercise.defaultReps + 1) }
        )

        if exercise.type == .weighted {
            EditorStepperRow(
                title: "DEFAULT WEIGHT",
                value: formattedWeight,
                onDecrement: { adjustWeight(by: -2.5) },
                onIncrement: { adjustWeight(by: 2.5) },
                trailing: {
                    weightUnitToggle
                }
            )
        }

        if exercise.type == .weighted, exercise.defaultWeightKg > 0 {
            let estimate = WorkoutAnalytics.epleyOneRM(
                weightKg: exercise.defaultWeightKg,
                reps: exercise.defaultReps
            )
            OneRMInlineBadge(estimateKg: estimate) {
                showOneRMDetail = true
            }
        }

        EditorStepperRow(
            title: "REST TIME",
            value: "\(exercise.restSeconds)s",
            onDecrement: { exercise.restSeconds = max(0, exercise.restSeconds - 15) },
            onIncrement: { exercise.restSeconds = min(300, exercise.restSeconds + 15) }
        )

        toggleRow(
            title: "WARMUP SETS",
            subtitle: "Adds 1 warmup set at 50% weight",
            isOn: $exercise.warmupSetsEnabled
        )

        notesSection

        substitutionSection
    }

    // MARK: - Timed (e.g. plank)

    @ViewBuilder
    private var timedContent: some View {
        EditorStepperRow(
            title: "DEFAULT SETS",
            value: "\(exercise.defaultSets)",
            onDecrement: { exercise.defaultSets = max(1, exercise.defaultSets - 1) },
            onIncrement: { exercise.defaultSets = min(10, exercise.defaultSets + 1) }
        )

        EditorStepperRow(
            title: "DEFAULT DURATION",
            value: formatDuration(exercise.defaultDurationSeconds),
            onDecrement: { exercise.defaultDurationSeconds = max(15, exercise.defaultDurationSeconds - 15) },
            onIncrement: { exercise.defaultDurationSeconds = min(7200, exercise.defaultDurationSeconds + 15) }
        )

        EditorStepperRow(
            title: "REST TIME",
            value: "\(exercise.restSeconds)s",
            onDecrement: { exercise.restSeconds = max(0, exercise.restSeconds - 15) },
            onIncrement: { exercise.restSeconds = min(300, exercise.restSeconds + 15) }
        )

        notesSection
        substitutionSection
    }

    // MARK: - Cardio

    @ViewBuilder
    private var cardioContent: some View {
        sectionLabel("MODE")
        HStack(spacing: 8) {
            ForEach(CardioTrackingMode.allCases) { mode in
                capsuleOption(
                    title: mode.title,
                    selected: exercise.cardioMode == mode
                ) {
                    exercise.cardioMode = mode
                    applyCardioModeDefaults()
                }
            }
        }

        if exercise.cardioMode == .distance || exercise.cardioMode == .both {
            EditorStepperRow(
                title: "DEFAULT DISTANCE",
                value: String(format: "%.1f km", exercise.defaultDistanceKm),
                onDecrement: { exercise.defaultDistanceKm = max(0, (exercise.defaultDistanceKm - 0.1 * 10).rounded() / 10) },
                onIncrement: { exercise.defaultDistanceKm = min(50, (exercise.defaultDistanceKm + 0.1 * 10).rounded() / 10) }
            )
        }

        if exercise.cardioMode == .duration || exercise.cardioMode == .both {
            EditorStepperRow(
                title: "DEFAULT DURATION",
                value: formatDuration(exercise.defaultDurationSeconds),
                onDecrement: { exercise.defaultDurationSeconds = max(60, exercise.defaultDurationSeconds - 15) },
                onIncrement: { exercise.defaultDurationSeconds = min(7200, exercise.defaultDurationSeconds + 15) }
            )
        }

        sectionLabel("INTENSITY")
        HStack(spacing: 8) {
            ForEach(CardioIntensity.allCases) { level in
                capsuleOption(
                    title: level.title,
                    selected: exercise.cardioIntensity == level
                ) {
                    exercise.cardioIntensity = level
                }
            }
        }

        if exercise.showsCardioEquipment {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("EQUIPMENT")
                TextField(exercise.equipmentFieldLabel, text: $exercise.equipmentSetting)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(fieldBackground)
                    )
            }
        }

        notesSection
        cardioSubstitutionSection
    }

    // MARK: - Shared sections

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOTES")
            TextField("Add workout notes...", text: $exercise.notes, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fieldBackground)
                )
        }
    }

    @ViewBuilder
    private var substitutionSection: some View {
        let alternatives = WorkoutExerciseCatalog.similarStrength(to: exercise)
        if !alternatives.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    sectionLabel("SIMILAR EXERCISES")
                    if !appState.isPro {
                        proBadge
                    }
                }

                if appState.isPro {
                    ForEach(alternatives) { item in
                        substitutionRow(emoji: item.emoji, name: item.name) {
                            applyStrengthSubstitution(item)
                        }
                    }
                } else {
                    ZStack {
                        VStack(spacing: 8) {
                            ForEach(alternatives) { item in
                                substitutionRow(emoji: item.emoji, name: item.name, disabled: true) {}
                            }
                        }
                        .blur(radius: 4)
                        .allowsHitTesting(false)

                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("Pro feature")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(mutedText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var cardioSubstitutionSection: some View {
        let alternatives = WorkoutExerciseCatalog.similarCardio(to: exercise)
        if !alternatives.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    sectionLabel("SIMILAR EXERCISES")
                    if !appState.isPro {
                        proBadge
                    }
                }

                if appState.isPro {
                    ForEach(alternatives) { item in
                        substitutionRow(emoji: item.emoji, name: item.name) {
                            applyCardioSubstitution(item)
                        }
                    }
                } else {
                    ZStack {
                        VStack(spacing: 8) {
                            ForEach(alternatives) { item in
                                substitutionRow(emoji: item.emoji, name: item.name, disabled: true) {}
                            }
                        }
                        .blur(radius: 4)
                        .allowsHitTesting(false)

                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("Pro feature")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(mutedText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Components

    private var weightUnitToggle: some View {
        HStack(spacing: 0) {
            ForEach(WeightDisplayUnit.allCases) { unit in
                Button {
                    exercise.weightUnit = unit
                } label: {
                    Text(unit.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(exercise.weightUnit == unit ? sheetBackground : mutedText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(exercise.weightUnit == unit ? accentGreen : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(fieldBackground))
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(mutedText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accentGreen)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fieldBackground)
        )
    }

    private func capsuleOption(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? sheetBackground : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selected ? accentGreen : fieldBackground)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : Color(hex: "#3A3A3A"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func substitutionRow(
        emoji: String,
        name: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 20))
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mutedText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fieldBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(sheetBackground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color(hex: "#F59E0B")))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(mutedText)
    }

    // MARK: - Helpers

    private var formattedWeight: String {
        switch exercise.weightUnit {
        case .kg:
            return String(format: "%.1f kg", exercise.defaultWeightKg)
        case .lbs:
            return String(format: "%.1f lbs", exercise.defaultWeightKg * 2.20462)
        }
    }

    private func adjustWeight(by deltaKg: Double) {
        exercise.defaultWeightKg = max(0, (exercise.defaultWeightKg + deltaKg * 10).rounded() / 10)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func applyCardioModeDefaults() {
        switch exercise.cardioMode {
        case .distance:
            if exercise.defaultDistanceKm == 0 { exercise.defaultDistanceKm = 3 }
        case .duration:
            if exercise.defaultDurationSeconds == 0 { exercise.defaultDurationSeconds = 20 * 60 }
        case .both:
            if exercise.defaultDistanceKm == 0 { exercise.defaultDistanceKm = 3 }
            if exercise.defaultDurationSeconds == 0 { exercise.defaultDurationSeconds = 20 * 60 }
        }
    }

    private func applyStrengthSubstitution(_ item: CatalogExercise) {
        exercise.name = item.name
        exercise.category = item.category
        exercise.type = item.type
        if item.type == .bodyweight {
            exercise.defaultWeightKg = 0
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func applyCardioSubstitution(_ item: CardioOption) {
        exercise.name = item.name
        exercise.category = .cardio
        exercise.type = .cardio
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Stepper row

private struct EditorStepperRow<Trailing: View>: View {
    let title: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        value: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.onDecrement = onDecrement
        self.onIncrement = onIncrement
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                Spacer()
                trailing()
            }

            HStack(spacing: 16) {
                Spacer()
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#6B7280"))
                }
                .buttonStyle(.plain)

                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 72)

                Button(action: onIncrement) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#22C55E"))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#2A2A2A"))
        )
    }
}
