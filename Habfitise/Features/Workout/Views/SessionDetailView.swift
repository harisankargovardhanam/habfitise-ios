import SwiftUI
import SwiftData

// MARK: - SessionDetailView (W6)

struct SessionDetailView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    let session: WorkoutSession
    var showsDoneButton: Bool = false

    @Query private var sets: [ExerciseSet]
    @State private var didCreateTemplate = false
    @State private var showDeleteConfirm = false

    private let sheetBackground = Color(hex: "#111111")
    private let cardBackground = Color(hex: "#2A2A2A")
    private let mutedText = Color(hex: "#9CA3AF")
    private let accentGreen = Color(hex: "#22C55E")
    private let prGold = Color(hex: "#F59E0B")

    init(session: WorkoutSession, showsDoneButton: Bool = false) {
        self.session = session
        self.showsDoneButton = showsDoneButton
        let sessionId = session.id
        _sets = Query(
            filter: #Predicate<ExerciseSet> { $0.sessionId == sessionId },
            sort: [SortDescriptor(\.setNumber)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                statsRow
                if let calories = session.totalCalories, calories > 0 {
                    EstimatedCaloriesBadge(calories: calories)
                }
                rpeIndicator
                exerciseBreakdown
                notesCard
                repeatButton
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(sheetBackground.ignoresSafeArea())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color(hex: "#EF4444"))
                }
            }

            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentGreen)
                }
            }
        }
        .alert("Delete workout?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout and its sets will be removed from all your devices.")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                WorkoutTypeBadge(type: session.type)
                Spacer()
            }

            Text(session.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text((session.completedAt ?? session.startedAt).formatted(date: .complete, time: .shortened))
                .font(.system(size: 14))
                .foregroundStyle(mutedText)

            Text(formatDuration(session.durationSeconds))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsRow: some View {
        if session.type == .cardio {
            HStack(spacing: 10) {
                statCard(value: formatDistance(totalDistanceKm), label: "Distance")
                statCard(value: formatDuration(session.durationSeconds), label: "Duration")
                statCard(value: formatPace(), label: "Pace")
            }
        } else {
            HStack(spacing: 10) {
                statCard(value: formatVolume(session.totalVolumeKg), label: "Volume")
                statCard(value: "\(workingSets.count)", label: "Sets")
                statCard(value: "\(exerciseGroups.count)", label: "Exercises")
            }
        }
    }

    @ViewBuilder
    private var rpeIndicator: some View {
        if session.perceivedExertion > 0 {
            HStack(spacing: 8) {
                Text("Effort: \(session.perceivedExertion)/10")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rpeColor(session.perceivedExertion))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(rpeColor(session.perceivedExertion).opacity(0.15))
                    )
            }
        }
    }

    // MARK: - Exercises

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(exerciseGroups, id: \.name) { group in
                ExerciseSummarySection(group: group)
            }
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if !session.notes.isEmpty {
            Text(session.notes)
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(mutedText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardBackground)
                )
        }
    }

    private var repeatButton: some View {
        Button {
            createTemplateFromSession()
        } label: {
            Text(didCreateTemplate ? "Template saved" : "Repeat this workout")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(didCreateTemplate ? mutedText : accentGreen)
                )
        }
        .buttonStyle(.plain)
        .disabled(didCreateTemplate)
    }

    // MARK: - Components

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
    }

    // MARK: - Data

    private var workingSets: [ExerciseSet] {
        sets.filter { !$0.isWarmup }
    }

    private var exerciseGroups: [ExerciseSummaryGroup] {
        let grouped = Dictionary(grouping: workingSets, by: \.exerciseName)
        return grouped.keys.sorted().map { name in
            let rows = grouped[name] ?? []
            return ExerciseSummaryGroup(
                name: name,
                sets: rows.sorted { $0.setNumber < $1.setNumber }
            )
        }
    }

    private var totalDistanceKm: Double {
        sets.compactMap(\.distanceKm).reduce(0, +)
    }

    private func createTemplateFromSession() {
        guard !didCreateTemplate else { return }

        let template = WorkoutTemplate(
            userId: session.userId.lowercased(),
            name: session.name,
            type: session.type,
            exercises: [],
            estimatedMinutes: max(session.durationSeconds / 60, 30),
            lastPerformedAt: session.completedAt ?? session.startedAt,
            notes: session.notes,
            synced: false
        )
        modelContext.insert(template)

        for (index, group) in exerciseGroups.enumerated() {
            let last = group.sets.last
            let type = inferExerciseType(from: group.sets)
            let category = ExerciseCategory(rawValue: last?.exerciseCategory ?? ExerciseCategory.full.rawValue) ?? .full

            let exercise = ExerciseTemplate(
                templateId: template.id,
                name: group.name,
                category: category,
                type: type,
                defaultSets: group.sets.count,
                defaultReps: last?.reps ?? 10,
                defaultWeightKg: last?.weightKg ?? 0,
                defaultDurationSeconds: last?.durationSeconds ?? 0,
                defaultDistanceKm: last?.distanceKm ?? 0,
                order: index,
                notes: "",
                template: template
            )
            modelContext.insert(exercise)
            template.exercises.append(exercise)
        }

        try? modelContext.save()
        didCreateTemplate = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func deleteSession() {
        let normalizedUserId = session.userId.lowercased()

        for set in sets {
            if set.synced {
                SyncDeletionQueue.record(
                    table: SyncTable.workoutSets,
                    id: set.id,
                    userId: normalizedUserId
                )
            }
            modelContext.delete(set)
        }

        if session.synced {
            SyncDeletionQueue.record(
                table: SyncTable.workoutSessions,
                id: session.id,
                userId: normalizedUserId
            )
        }
        modelContext.delete(session)
        try? modelContext.save()

        syncService.schedulePush(modelContext: modelContext, userId: normalizedUserId)
        dismiss()
    }

    private func inferExerciseType(from sets: [ExerciseSet]) -> ExerciseType {
        if sets.contains(where: { ($0.distanceKm ?? 0) > 0 || ($0.durationSeconds ?? 0) > 0 }) {
            return session.type == .cardio ? .cardio : .timed
        }
        if sets.contains(where: { ($0.weightKg ?? 0) > 0 }) {
            return .weighted
        }
        return .bodyweight
    }

    private func rpeColor(_ value: Int) -> Color {
        switch value {
        case 1...3: Color(hex: "#3B82F6")
        case 4...6: accentGreen
        case 7...8: Color(hex: "#FF6B35")
        default: Color(hex: "#FF4444")
        }
    }

    private func formatVolume(_ kg: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: kg)) ?? "\(Int(kg))"
        return "\(value) kg"
    }

    private func formatDistance(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 { return "\(max(minutes, 1))m" }
        return "\(minutes)m \(remainder)s"
    }

    private func formatPace() -> String {
        let distance = totalDistanceKm
        guard distance > 0, session.durationSeconds > 0 else { return "—" }
        let paceSeconds = Double(session.durationSeconds) / distance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - Exercise summary

struct ExerciseSummaryGroup {
    let name: String
    let sets: [ExerciseSet]
}

struct ExerciseSummarySection: View {
    let group: ExerciseSummaryGroup

    private let cardBackground = Color(hex: "#2A2A2A")
    private let mutedText = Color(hex: "#9CA3AF")
    private let prGold = Color(hex: "#F59E0B")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                HStack {
                    headerCell("Set", width: 36)
                    headerCell("Reps")
                    headerCell("Weight")
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(hex: "#1A1A1A"))

                ForEach(group.sets, id: \.id) { set in
                    setRow(set)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(cardBackground)
            )
        }
    }

    private func headerCell(_ title: String, width: CGFloat? = nil) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(mutedText)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func setRow(_ set: ExerciseSet) -> some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .leading)

            Text(setValue(set.reps.map(String.init) ?? "—"))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(set.weightKg.map { String(format: "%.1f kg", $0) } ?? cardioValue(set))
                .frame(maxWidth: .infinity, alignment: .leading)

            if set.isPersonalRecord {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("PR")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(prGold)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            set.isPersonalRecord
                ? prGold.opacity(0.1)
                : Color.clear
        )
    }

    private func setValue(_ value: String) -> String { value }

    private func cardioValue(_ set: ExerciseSet) -> String {
        if let km = set.distanceKm, km > 0 {
            return String(format: "%.1f km", km)
        }
        if let seconds = set.durationSeconds, seconds > 0 {
            let m = seconds / 60
            let s = seconds % 60
            return String(format: "%d:%02d", m, s)
        }
        return "—"
    }
}
