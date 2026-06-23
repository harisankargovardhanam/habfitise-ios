import SwiftUI

// MARK: - WorkoutCompleteView (W3)

enum WorkoutRepeatOption: String, CaseIterable, Identifiable {
    case tomorrow
    case in2Days
    case in3Days
    case nextWeek
    case pickDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tomorrow: "Tomorrow"
        case .in2Days: "In 2 days"
        case .in3Days: "In 3 days"
        case .nextWeek: "Next week"
        case .pickDate: "Pick date"
        }
    }

    var repeatSchedule: RepeatSchedule {
        switch self {
        case .tomorrow: .nextDay
        case .in2Days: .in2Days
        case .in3Days: .in3Days
        case .nextWeek: .nextWeekSameDay
        case .pickDate: .custom
        }
    }
}

struct WorkoutCompleteView: View {
    let payload: WorkoutCompletePayload
    let template: WorkoutTemplate?
    let onFinish: (WorkoutCompleteResult) -> Void

    @Environment(ThemeManager.self) private var theme

    @State private var step: Step = .rpe
    @State private var selectedRPE = 5
    @State private var scheduleRepeat = true
    @State private var selectedRepeat: WorkoutRepeatOption
    @State private var customRepeatDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    @State private var notes: String
    @State private var showDatePicker = false
    @State private var showConfetti = false
    @State private var prBadgeScales: [UUID: CGFloat] = [:]

    private enum Step {
        case rpe
        case summary
    }

    init(
        payload: WorkoutCompletePayload,
        template: WorkoutTemplate? = nil,
        onFinish: @escaping (WorkoutCompleteResult) -> Void
    ) {
        self.payload = payload
        self.template = template
        self.onFinish = onFinish
        _notes = State(initialValue: payload.sessionNotes)
        _selectedRepeat = State(
            initialValue: payload.workoutType == .cardio ? .tomorrow : .in2Days
        )
    }

    /// Legacy single-callback initializer.
    init(stats: WorkoutCompletionStats, workoutName: String, onDone: @escaping () -> Void) {
        let payload = WorkoutCompletePayload(stats: stats, workoutName: workoutName)
        self.payload = payload
        self.template = nil
        self.onFinish = { _ in onDone() }
        _notes = State(initialValue: "")
        _selectedRepeat = State(initialValue: .in2Days)
    }

    var body: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            Group {
                switch step {
                case .rpe:
                    rpeStep
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .summary:
                    summaryStep
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: step)
        }
        .fullScreenWidthBounds()
        .preferredColorScheme(theme.preferredColorScheme)
    }

    // MARK: - Step 1: RPE

    private var rpeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: HabfitiseSpacing.xl)

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("How hard was that?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Rate your effort")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                GeometryReader { geo in
                    let spacing: CGFloat = 6
                    let horizontalPadding: CGFloat = 24
                    let availableWidth = max(geo.size.width - horizontalPadding, 0)
                    let pillSize = min(36, floor((availableWidth - spacing * 9) / 10))

                    HStack(spacing: spacing) {
                        ForEach(1...10, id: \.self) { value in
                            rpePill(value, size: pillSize)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 44)
                .padding(.horizontal, 12)

                HStack {
                    rpeLegend("Easy", value: 1)
                    Spacer()
                    rpeLegend("Moderate", value: 5)
                    Spacer()
                    rpeLegend("Hard", value: 8)
                    Spacer()
                    rpeLegend("Max", value: 10)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: HabfitiseSpacing.xl)

            Button {
                withAnimation { step = .summary }
                triggerSummaryAnimations()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.textOnBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(theme.colors.accentGreen))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .safeAreaPadding(.bottom, HabfitiseSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rpePill(_ value: Int, size: CGFloat) -> some View {
        let selected = selectedRPE == value
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                selectedRPE = value
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("\(value)")
                .font(.system(size: min(16, size * 0.45), weight: .bold))
                .foregroundStyle(selected ? theme.colors.textOnBackground : rpeColor(value))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(selected ? rpeColor(value) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(rpeColor(value), lineWidth: selected ? 0 : 1.5)
                )
                .scaleEffect(selected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
    }

    private func rpeLegend(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
            Text("(\(value))")
                .font(.system(size: 11))
        }
    }

    private func rpeColor(_ value: Int) -> Color {
        switch value {
        case 1...3: Color(hex: "#3B82F6")
        case 4...6: Color(hex: "#22C55E")
        case 7...8: Color(hex: "#FF6B35")
        default: Color(hex: "#FF4444")
        }
    }

    // MARK: - Step 2: Summary

    private var summaryStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ZStack {
                    HabfitiseCelebrationBurst()
                        .opacity(showConfetti ? 1 : 0)

                    HabfitiseLottieOrFallback(lottieName: "success", height: 120) {
                        HabfitiseAnimatedSuccessMark()
                    }
                    .frame(width: 120, height: 120)
                }
                .padding(.top, 16)

                VStack(spacing: 6) {
                    Text("Session Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("\(payload.workoutName) · \(payload.completedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                statsCard

                if !payload.newPRs.isEmpty {
                    prSection
                }

                repeatSection
                notesSection

                Button(action: finish) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.colors.textOnBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.colors.accentGreen)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .safeAreaPadding(.bottom, HabfitiseSpacing.xl)
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Repeat date", selection: $customRepeatDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(theme.colors.background)
                    .navigationTitle("Pick date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showDatePicker = false }
                                .foregroundStyle(theme.colors.accentGreen)
                        }
                    }
            }
            .presentationDetents([.medium])
            .environment(theme)
        }
    }

    private var statsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                statColumn(value: formattedDuration, label: "Duration")
                statColumn(value: "\(Int(payload.totalVolumeKg)) kg", label: "Volume")
                statColumn(value: "\(payload.totalSets) sets", label: "Sets")
            }
            if payload.estimatedCalories > 0 {
                EstimatedCaloriesBadge(calories: payload.estimatedCalories)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEW PERSONAL RECORDS 🏆")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#F59E0B"))

            ForEach(Array(payload.newPRs.enumerated()), id: \.element.id) { index, pr in
                PRBadgeRow(record: pr)
                    .scaleEffect(prBadgeScales[pr.id] ?? 0.6)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(Double(index) * 0.1)) {
                            prBadgeScales[pr.id] = 1
                        }
                    }
            }
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Repeat this workout?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
            Text("We'll remind you and add it to your schedule")
                .font(.system(size: 13))
                .foregroundStyle(theme.colors.textSecondary)

            Toggle("Schedule repeat", isOn: $scheduleRepeat)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textPrimary)
                .tint(theme.colors.accentGreen)

            if scheduleRepeat {
                Text("When?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WorkoutRepeatOption.allCases) { option in
                            repeatChip(option)
                        }
                    }
                }
            } else {
                Text("No problem — you can always repeat from your templates")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.fieldBackground)
        )
    }

    private func repeatChip(_ option: WorkoutRepeatOption) -> some View {
        let selected = selectedRepeat == option
        return Button {
            selectedRepeat = option
            if option == .pickDate {
                showDatePicker = true
            }
        } label: {
            Text(option.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? theme.colors.textOnBackground : theme.colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selected ? theme.colors.accentGreen : theme.colors.chipBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.clear : theme.colors.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var notesSection: some View {
        TextField("Add workout notes...", text: $notes, axis: .vertical)
            .lineLimit(3...6)
            .font(.system(size: 15))
            .foregroundStyle(theme.colors.textPrimary)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.colors.fieldBackground)
            )
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDuration: String {
        let minutes = payload.durationSeconds / 60
        let seconds = payload.durationSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    private func triggerSummaryAnimations() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            showConfetti = false
        }
    }

    private func finish() {
        let result = WorkoutCompleteResult(
            perceivedExertion: selectedRPE,
            notes: notes,
            scheduleRepeat: scheduleRepeat,
            repeatSchedule: scheduleRepeat ? selectedRepeat.repeatSchedule : nil,
            customRepeatDate: selectedRepeat == .pickDate ? customRepeatDate : nil
        )
        onFinish(result)
    }
}

// MARK: - PR badge

private struct PRBadgeRow: View {
    let record: WorkoutCompletePR

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#F59E0B"))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(record.newValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                    if let previous = record.previousValue {
                        Text("↑ from \(previous)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#2A2A2A"))
        )
    }
}

typealias WorkoutCompleteSheet = WorkoutCompleteView

#if DEBUG
struct WorkoutCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutCompleteView(
            payload: WorkoutCompletePayload(
                workoutName: "Push Day A",
                workoutType: .weights,
                durationSeconds: 2732,
                totalVolumeKg: 4200,
                totalSets: 16,
                sessionNotes: "",
                newPRs: [
                    WorkoutCompletePR(exerciseName: "Bench Press", newValue: "80 kg", previousValue: "75 kg")
                ]
            )
        ) { _ in }
    }
}
#endif
