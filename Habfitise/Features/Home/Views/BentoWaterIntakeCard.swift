import SwiftUI

// MARK: - Water intake card (full-width horizontal)

struct BentoWaterIntakeCard: View {
    let currentML: Int
    let goalML: Int
    let filledGlasses: Int
    let glassCount: Int
    let onLogGlass: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var animatedBottleLevel: Double = 1
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(currentML) / Double(goalML), 1)
    }

    /// Bottle drains as you drink toward your daily goal.
    private var bottleLevel: Double {
        guard goalML > 0 else { return 1 }
        return max(0, 1 - progress)
    }

    private var percent: Int {
        Int((progress * 100).rounded())
    }

    private var remainingML: Int {
        max(0, goalML - currentML)
    }

    var body: some View {
        BentoCardContainer(title: "Water", accent: .water) {
            VStack(alignment: .leading, spacing: HabfitiseSpacing.md) {
                HStack(alignment: .center, spacing: HabfitiseSpacing.lg) {
                    WaterBottleView(level: animatedBottleLevel)
                        .frame(width: 56, height: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(currentML.formatted())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("ml")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.colors.textSecondary)
                        }

                        Text("of \(goalML.formatted()) ml goal")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)

                        HStack(spacing: HabfitiseSpacing.sm) {
                            Capsule()
                                .fill(theme.colors.trackBackground)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(theme.colors.waterBlue)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .scaleEffect(x: animatedProgress, anchor: .leading)
                                }
                                .frame(height: 10)

                            Text("\(percent)%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.colors.waterBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(theme.colors.waterBlue.opacity(0.14))
                                )
                                .fixedSize()
                        }

                        Text("\(remainingML.formatted()) ml remaining")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: HabfitiseSpacing.sm) {
                    HStack {
                        Text("GLASSES")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.colors.textSecondary)

                        Spacer(minLength: 0)

                        Text("\(filledGlasses) / \(glassCount)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        ForEach(0..<glassCount, id: \.self) { index in
                            Button(action: onLogGlass) {
                                WaterGlassIcon(
                                    isFilled: index < filledGlasses,
                                    size: 16
                                )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                animatedBottleLevel = bottleLevel
                animatedProgress = progress
            }
        }
        .onChange(of: bottleLevel) { _, newValue in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                animatedBottleLevel = newValue
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Bottle visual

private struct WaterBottleView: View {
    let level: Double

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        let bottle = WaterBottleOutlineShape()

        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 2.2

            ZStack {
                bottle
                    .fill(theme.colors.trackBackground.opacity(0.22))

                bottle
                    .stroke(theme.colors.trackBackground, lineWidth: 1.5)

                WaveWaterFill(level: level, wavePhase: phase)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.colors.waterBlue.opacity(0.65),
                                theme.colors.waterBlue
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .mask(bottle)
            }
        }
    }
}

private struct WaterBottleOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2

        let capWidth = width * 0.34
        let capHeight = height * 0.08
        let neckWidth = width * 0.28
        let neckHeight = height * 0.14
        let bodyWidth = width * 0.62
        let cornerRadius = bodyWidth * 0.2

        let bodyTop = capHeight + neckHeight
        let bodyHeight = height - bodyTop - height * 0.02
        let bodyLeft = centerX - bodyWidth / 2

        var path = Path()

        let capRect = CGRect(
            x: centerX - capWidth / 2,
            y: 0,
            width: capWidth,
            height: capHeight
        )
        path.addRoundedRect(in: capRect, cornerSize: CGSize(width: 3, height: 3))

        let neckRect = CGRect(
            x: centerX - neckWidth / 2,
            y: capHeight,
            width: neckWidth,
            height: neckHeight
        )
        path.addRect(neckRect)

        let bodyRect = CGRect(
            x: bodyLeft,
            y: bodyTop,
            width: bodyWidth,
            height: bodyHeight
        )
        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        return path
    }
}

private struct WaveWaterFill: Shape {
    var level: Double
    var wavePhase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, wavePhase) }
        set {
            level = newValue.first
            wavePhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0.01 else { return Path() }

        let fillHeight = rect.height * CGFloat(level)
        let baseY = rect.height - fillHeight
        let waveAmplitude = min(5, max(2.5, fillHeight * 0.1))

        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseY))

        let steps = max(Int(rect.width / 2), 12)
        for step in 0...steps {
            let x = rect.width * CGFloat(step) / CGFloat(steps)
            let normalized = CGFloat(step) / CGFloat(steps)
            let primary = sin((normalized * .pi * 2) + CGFloat(wavePhase))
            let secondary = sin((normalized * .pi * 4) + CGFloat(wavePhase * 1.4)) * 0.35
            let y = baseY + (primary + secondary) * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
struct BentoWaterIntakeCard_Previews: PreviewProvider {
    static var previews: some View {
        BentoWaterIntakeCard(
            currentML: 6375,
            goalML: 3000,
            filledGlasses: 8,
            glassCount: 8,
            onLogGlass: {}
        )
        .padding()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
    }
}
#endif
