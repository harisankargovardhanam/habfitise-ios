import SwiftUI

struct BentoDailyMovementCard: View {
    @Environment(ThemeManager.self) private var theme

    let connectionState: HomeHealthConnectionState
    let summary: DailyActivitySummary
    let isPro: Bool
    let onConnect: () -> Void
    var onEditStepGoal: (() -> Void)?
    var onOpenHealth: (() -> Void)?
    var onRefresh: (() -> Void)?

    private let moveColor = Color(hex: "#FF375F")
    private let exerciseColor = Color(hex: "#A6FF00")
    private let workoutColor = Color(hex: "#BF5AF2")
    private let distanceColor = Color(hex: "#00D4FF")

    var body: some View {
        switch connectionState {
        case .unavailable:
            Text("Apple Health isn't available on this device.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        case .notConnected:
            connectPrompt
        case .denied:
            deniedPrompt
        case .connected:
            connectedBody
        }
    }

    private var connectPrompt: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(spacing: HabfitiseSpacing.md) {
                ZStack {
                    Circle()
                        .fill(moveColor.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(moveColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Movement + training")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Steps from Apple Health, workouts from VAYA — one daily picture.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onConnect) {
                HStack(spacing: 8) {
                    if !isPro {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isPro ? "Connect Apple Health" : "Unlock with Pro")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(theme.colors.textOnBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(theme.colors.accentGreen))
            }
            .buttonStyle(.plain)
        }
    }

    private var deniedPrompt: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(spacing: HabfitiseSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health access needed")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Turn on Steps in the Health app, then tap Refresh.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: HabfitiseSpacing.sm) {
                Button {
                    onOpenHealth?()
                } label: {
                    Text("Open Health")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(theme.colors.fieldBackground))
                }
                .buttonStyle(.plain)

                Button {
                    onRefresh?()
                } label: {
                    Text("Refresh")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textOnBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(theme.colors.accentGreen))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var connectedBody: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                dualRing

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.health.steps.formatted())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: summary.health.steps)

                    Text("Steps today")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)

                    Text("\(Int(summary.stepProgress * 100))% of \(summary.health.stepGoal.formatted()) goal")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(moveColor)

                    if summary.health.steps == 0 {
                        Text("No steps yet today. Check Health → Sharing → Apps → VAYA if this looks wrong.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onEditStepGoal {
                        Button(action: onEditStepGoal) {
                            Label("Edit goal", systemImage: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }

            if summary.hasCompletedWorkoutToday {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(workoutColor)
                    Text("VAYA workout · \(summary.workoutMinutesToday) min · \(Int(summary.workoutVolumeKg)) kg volume")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(workoutColor.opacity(0.1))
                )
            }

            HStack(spacing: 0) {
                metricTile(
                    icon: "flame.fill",
                    value: "\(summary.health.activeEnergyKcal)",
                    unit: "kcal",
                    label: "Move",
                    tint: moveColor
                )
                divider
                metricTile(
                    icon: "figure.run",
                    value: "\(summary.combinedExerciseMinutes)",
                    unit: "min",
                    label: "Exercise",
                    tint: exerciseColor
                )
                divider
                metricTile(
                    icon: "location.fill",
                    value: summary.health.formattedDistance,
                    unit: nil,
                    label: "Distance",
                    tint: distanceColor
                )
            }
            .padding(.vertical, HabfitiseSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.colors.fieldBackground)
            )

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(moveColor.opacity(0.8))
                Text("Apple Health + VAYA workouts")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
    }

    private var dualRing: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.trackBackground, lineWidth: 8)

            Circle()
                .trim(from: 0, to: summary.stepProgress)
                .stroke(moveColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .inset(by: 12)
                .stroke(theme.colors.trackBackground.opacity(0.8), lineWidth: 5)

            Circle()
                .inset(by: 12)
                .trim(from: 0, to: summary.exerciseProgress)
                .stroke(exerciseColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: summary.hasCompletedWorkoutToday ? "figure.strengthtraining.traditional" : "figure.walk")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(summary.hasCompletedWorkoutToday ? workoutColor : moveColor)
        }
        .frame(width: 78, height: 78)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: summary.stepProgress)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: summary.exerciseProgress)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.colors.cardBorder.opacity(0.6))
            .frame(width: 1)
            .padding(.vertical, 10)
    }

    private func metricTile(
        icon: String,
        value: String,
        unit: String?,
        label: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
