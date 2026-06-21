import SwiftUI
import SwiftData

// MARK: - W7A Volume progress chip

struct VolumeProgressChip: View {
    let hint: VolumeProgressHint

    var body: some View {
        Text(hint.message)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(hex: hint.colorHex))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(hex: hint.colorHex).opacity(0.12)))
    }
}

// MARK: - W7B Streak card

struct WorkoutStreakCard: View {
    @Environment(ThemeManager.self) private var theme

    let stats: WorkoutStreakStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if stats.hasActiveStreak {
                Text("🔥 \(stats.currentStreak) workout streak")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.percentageOrange)
                Text("Keep it going!")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
            } else {
                Text("Start a new streak today")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.accentGreen)
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(theme.colors.trackBackground, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: stats.consistency30Day)
                        .stroke(
                            theme.colors.accentGreen,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(stats.consistency30Day * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text("30-day consistency")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("This month: \(stats.monthCompleted)/\(stats.monthPlanned) planned")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                    Text("Personal best: \(stats.bestStreak) days")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textTertiary)
                }
            }
        }
        .padding(BentoCardStyle.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bentoCardSurface()
    }
}

// MARK: - W7C 1RM

struct OneRMInlineBadge: View {
    let estimateKg: Double
    let onInfoTap: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Estimated 1RM: \(String(format: "%.0f", estimateKg)) kg")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#F59E0B"))
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
            .buttonStyle(.plain)
        }
    }
}

struct OneRMDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let history: [OneRMHistoryPoint]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Epley formula: weight × (1 + reps ÷ 30)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#9CA3AF"))

                if history.isEmpty {
                    Text("Log more weighted sets to see progress.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                } else {
                    OneRMLineChart(points: history)
                        .frame(height: 180)

                    ForEach(history.suffix(5).reversed()) { point in
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(String(format: "%.0f kg", point.valueKg))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(Color(hex: "#111111").ignoresSafeArea())
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#22C55E"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct OneRMLineChart: View {
    let points: [OneRMHistoryPoint]

    var body: some View {
        GeometryReader { geo in
            let values = points.map(\.valueKg)
            let minV = (values.min() ?? 0) * 0.9
            let maxV = (values.max() ?? 1) * 1.05
            let range = max(maxV - minV, 1)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#2A2A2A"))

                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let y = geo.size.height * (1 - CGFloat((point.valueKg - minV) / range))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color(hex: "#22C55E"), lineWidth: 2)
                .padding(12)
            }
        }
    }
}

// MARK: - W7E Body weight

struct BodyWeightCard: View {
    let entries: [BodyWeightEntry]
    let targetWeightKg: Double
    let startWeightKg: Double?

    private let cardBackground = Color(hex: "#2A2A2A")
    private let accentGreen = Color(hex: "#22C55E")
    private let mutedText = Color(hex: "#9CA3AF")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body Weight")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            if let current = entries.sorted(by: { $0.loggedAt > $1.loggedAt }).first {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f kg", current.weightKg))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    if let start = startWeightKg {
                        let delta = current.weightKg - start
                        Text(String(format: "%+.1f kg since start", delta))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(delta <= 0 ? accentGreen : mutedText)
                    }
                }
            }

            BodyWeightLineChart(entries: entries, goalKg: targetWeightKg > 0 ? targetWeightKg : nil)
                .frame(height: 140)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cardBackground))
    }
}

struct BodyWeightLineChart: View {
    let entries: [BodyWeightEntry]
    let goalKg: Double?

    var body: some View {
        GeometryReader { geo in
            let sorted = entries.sorted { $0.loggedAt < $1.loggedAt }
            let values = sorted.map(\.weightKg)
            let minV = (values.min() ?? 0) - 2
            let maxV = (values.max() ?? 1) + 2
            let range = max(maxV - minV, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#1A1A1A"))

                if let goalKg, goalKg >= minV, goalKg <= maxV {
                    let y = geo.size.height * (1 - CGFloat((goalKg - minV) / range))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color(hex: "#3B82F6").opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }

                Path { path in
                    for (index, entry) in sorted.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(max(sorted.count - 1, 1))
                        let y = geo.size.height * (1 - CGFloat((entry.weightKg - minV) / range))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color(hex: "#22C55E"), lineWidth: 2)
                .padding(10)
            }
        }
    }
}

struct BodyWeightLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let userId: String
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Weight (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#2A2A2A")))
                    .padding(.horizontal, 20)

                Button("Save") {
                    guard let weight = Double(weightText), weight > 0 else { return }
                    let entry = BodyWeightEntry(userId: userId, weightKg: weight, synced: false)
                    modelContext.insert(entry)
                    try? modelContext.save()
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#22C55E")))
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 24)
            .background(Color(hex: "#111111").ignoresSafeArea())
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WorkoutStartWeightPrompt: View {
    @Environment(ThemeManager.self) private var theme

    @Binding var weightText: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BentoCardStyle.compactContentSpacing) {
            BentoCardHeader(title: "Log Today's Weight", accent: .bodyWeight)

            HStack(alignment: .center, spacing: HabfitiseSpacing.md) {
                VStack(alignment: .leading, spacing: BentoCardStyle.compactContentSpacing) {
                    HStack(spacing: HabfitiseSpacing.sm) {
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(theme.colors.fieldBackground)
                            )
                            .frame(maxWidth: 88)

                        Button("Save", action: onSave)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.colors.accentGreen)
                    }

                    Button("Not now", action: onDismiss)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    BentoMicroSparkline(accent: theme.colors.accentGreen)
                        .frame(width: 108, height: 36)

                    Capsule()
                        .fill(theme.colors.trackBackground)
                        .frame(width: 108, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(theme.colors.accentGreen.opacity(0.85))
                                .frame(width: 72, height: 6)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bentoCardSurface(compact: true)
    }
}

/// Decorative trend line for compact tracking cards.
struct BentoMicroSparkline: View {
    let accent: Color

    private let samples: [CGFloat] = [0.72, 0.68, 0.70, 0.66, 0.64, 0.62, 0.58]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.08))

                Path { path in
                    for (index, sample) in samples.enumerated() {
                        let x = geo.size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                        let y = geo.size.height * (1 - sample)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - W7F Calories

struct EstimatedCaloriesBadge: View {
    let calories: Int
    @State private var showTooltip = false

    var body: some View {
        Button {
            showTooltip.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#FF6B35"))
                Text("~\(calories) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: "#2A2A2A")))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTooltip) {
            Text("Estimated from your weight, workout type, and duration. Actual burn varies.")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - W7G AI suggestion

struct WorkoutAISuggestionCard: View {
    let suggestion: WorkoutSuggestion
    let isPro: Bool
    let onSave: () -> Void
    let onDismiss: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Based on your history, you might enjoy:")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
            }

            HStack {
                WorkoutTypeBadge(type: suggestion.type)
                Text(suggestion.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(suggestion.reason)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#9CA3AF"))

            if isPro {
                Button("Save template", action: onSave)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#22C55E")))
            } else {
                Button("Unlock with Pro", action: onUpgrade)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#F59E0B")))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "#2A2A2A")))
    }
}

// MARK: - W7D Superset link

struct SupersetLinkIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color(hex: "#22C55E"))
                .frame(width: 3, height: 20)
            Text("SUPERSET")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#22C55E"))
            Rectangle()
                .fill(Color(hex: "#22C55E"))
                .frame(width: 3, height: 20)
        }
        .frame(maxWidth: .infinity)
    }
}
