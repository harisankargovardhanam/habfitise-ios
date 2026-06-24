import SwiftUI

// MARK: - Water intake (Home bento)

struct BentoWaterIntakeCard: View {
    let currentML: Int
    let goalML: Int
    let glassVolumeML: Int
    let filledGlasses: Int
    let glassCount: Int
    let onQuickAdd: (Int) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(currentML) / Double(goalML), 1)
    }

    private var isGoalMet: Bool {
        goalML > 0 && currentML >= goalML
    }

    private var remainingML: Int {
        max(0, goalML - currentML)
    }

    private var statusLine: String {
        if isGoalMet {
            return "Daily goal reached"
        }
        if remainingML >= 1000 {
            return String(format: "%.1f L to go", Double(remainingML) / 1000)
        }
        return "\(remainingML.formatted()) ml to go"
    }

    var body: some View {
        BentoCardContainer(title: "Hydration", accent: .water) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.lg) {
                HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                    hydrationRing

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(currentML.formatted())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.colors.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(nil, value: currentML)

                            Text("ml")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.colors.textSecondary)
                        }

                        Text("of \(goalML.formatted()) ml")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)

                        Label(statusLine, systemImage: isGoalMet ? "checkmark.seal.fill" : "drop.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(isGoalMet ? theme.colors.accentGreen : theme.colors.waterBlue)
                            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                glassProgressRow

                quickAddRow
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
                animatedProgress = newValue
            }
        }
    }

    private var hydrationRing: some View {
        let waterColor = theme.colors.waterBlue

        return ZStack {
            Circle()
                .stroke(theme.colors.trackBackground, lineWidth: 10)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [waterColor.opacity(0.55), waterColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                ZStack {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colors.textPrimary)
                        .opacity(isGoalMet ? 0 : 1)

                    if isGoalMet {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(waterColor)
                    }
                }
                .frame(width: 44, height: 22)

                Text("\(filledGlasses)/\(glassCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
        .frame(width: 84, height: 84)
        .contentShape(Circle())
        .onTapGesture {
            onQuickAdd(glassVolumeML)
        }
        .accessibilityLabel("Log one glass of water")
        .accessibilityHint("\(glassVolumeML) milliliters")
    }

    private var glassProgressRow: some View {
        HStack(spacing: 5) {
            ForEach(0..<glassCount, id: \.self) { index in
                Capsule()
                    .fill(index < filledGlasses ? theme.colors.waterBlue : theme.colors.trackBackground)
                    .frame(height: 6)
            }
        }
        .animation(.easeOut(duration: 0.25), value: filledGlasses)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filledGlasses) of \(glassCount) glasses logged")
    }

    private var quickAddRow: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            quickAddButton(title: "+250", subtitle: "ml") {
                onQuickAdd(250)
            }
            quickAddButton(title: "+500", subtitle: "ml") {
                onQuickAdd(500)
            }
            quickAddButton(title: "Glass", subtitle: "\(glassVolumeML) ml", prominent: true) {
                onQuickAdd(glassVolumeML)
            }
        }
    }

    private func quickAddButton(
        title: String,
        subtitle: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(prominent ? theme.colors.textOnBackground.opacity(0.85) : theme.colors.textTertiary)
            }
            .foregroundStyle(prominent ? theme.colors.textOnBackground : theme.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? theme.colors.waterBlue : theme.colors.fieldBackground)
            )
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.97))
    }
}

#if DEBUG
struct BentoWaterIntakeCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BentoWaterIntakeCard(
                currentML: 1750,
                goalML: 2500,
                glassVolumeML: 313,
                filledGlasses: 5,
                glassCount: 8,
                onQuickAdd: { _ in }
            )

            BentoWaterIntakeCard(
                currentML: 2600,
                goalML: 2500,
                glassVolumeML: 313,
                filledGlasses: 8,
                glassCount: 8,
                onQuickAdd: { _ in }
            )
        }
        .padding()
        .environment(ThemeManager())
    }
}
#endif
