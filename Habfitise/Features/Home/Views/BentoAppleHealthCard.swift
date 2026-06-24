import SwiftUI

struct BentoAppleHealthCard: View {
    @Environment(ThemeManager.self) private var theme

    let connectionState: HomeHealthConnectionState
    let snapshot: HomeHealthSnapshot
    let isLoading: Bool
    let isPro: Bool
    let onConnect: () -> Void

    private let moveColor = Color(hex: "#FF375F")
    private let exerciseColor = Color(hex: "#A6FF00")
    private let distanceColor = Color(hex: "#00D4FF")

    var body: some View {
        switch connectionState {
        case .unavailable:
            unavailableBody
        case .notConnected, .denied:
            connectBody
        case .connected:
            connectedBody
        }
    }

    private var unavailableBody: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
            Text("Apple Health isn't available on this device.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var connectBody: some View {
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
                    Text("Your daily movement")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Steps, active energy, exercise, and distance from Apple Health.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if connectionState == .denied {
                Text("Turn on Health access in Settings → Privacy → Health.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textSecondary)
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

    private var connectedBody: some View {
        VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
            HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                stepsRing

                VStack(alignment: .leading, spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .tint(moveColor)
                    } else {
                        Text(snapshot.steps.formatted())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.colors.textPrimary)
                            .contentTransition(.numericText())
                    }

                    Text("Steps today")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.colors.textSecondary)

                    Text("\(Int(snapshot.stepProgress * 100))% of \(snapshot.stepGoal.formatted()) goal")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(moveColor)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                metricTile(
                    icon: "flame.fill",
                    value: "\(snapshot.activeEnergyKcal)",
                    unit: "kcal",
                    label: "Move",
                    tint: moveColor
                )

                divider

                metricTile(
                    icon: "figure.run",
                    value: "\(snapshot.exerciseMinutes)",
                    unit: "min",
                    label: "Exercise",
                    tint: exerciseColor
                )

                divider

                metricTile(
                    icon: "location.fill",
                    value: snapshot.formattedDistance,
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
                Text("Data from Apple Health")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
    }

    private var stepsRing: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.trackBackground, lineWidth: 8)

            Circle()
                .trim(from: 0, to: snapshot.stepProgress)
                .stroke(
                    moveColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(moveColor)
        }
        .frame(width: 72, height: 72)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: snapshot.stepProgress)
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

#if DEBUG
struct BentoAppleHealthCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BentoAppleHealthCard(
                connectionState: .notConnected,
                snapshot: .empty,
                isLoading: false,
                isPro: true,
                onConnect: {}
            )
            BentoAppleHealthCard(
                connectionState: .connected,
                snapshot: HomeHealthSnapshot(
                    steps: 8_432,
                    stepGoal: 10_000,
                    activeEnergyKcal: 420,
                    exerciseMinutes: 32,
                    distanceMeters: 5_240
                ),
                isLoading: false,
                isPro: true,
                onConnect: {}
            )
        }
        .padding()
        .background(Color.black)
        .environment(ThemeManager())
    }
}
#endif
