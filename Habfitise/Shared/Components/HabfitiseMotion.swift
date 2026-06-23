import SwiftUI

// MARK: - Animation tokens

extension HabfitiseAnimation {
    static let celebrate = Animation.spring(response: 0.52, dampingFraction: 0.68)
    static let stagger = Animation.spring(response: 0.55, dampingFraction: 0.84)
    static let float = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    static let breathe = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
}

// MARK: - Staggered entrance

private struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 22)
            .scaleEffect(isVisible ? 1 : 0.94)
            .onAppear {
                withAnimation(HabfitiseAnimation.stagger.delay(Double(index) * 0.07)) {
                    isVisible = true
                }
            }
    }
}

private struct FloatingMotionModifier: ViewModifier {
    @State private var floating = false
    let amplitude: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: floating ? -amplitude : amplitude)
            .onAppear {
                withAnimation(HabfitiseAnimation.float) {
                    floating = true
                }
            }
    }
}

private struct TabBounceModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isActive) { _, active in
                guard active else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
                    scale = 1.22
                }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62).delay(0.1)) {
                    scale = 1
                }
            }
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            .clear,
                            theme.colors.cardBackground.opacity(0.55),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.45)
                    .offset(x: phase * proxy.size.width * 1.4)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func habfitiseStaggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }

    func habfitiseFloating(amplitude: CGFloat = 6) -> some View {
        modifier(FloatingMotionModifier(amplitude: amplitude))
    }

    func habfitiseTabBounce(isActive: Bool) -> some View {
        modifier(TabBounceModifier(isActive: isActive))
    }

    func habfitiseShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Breathing loader

struct HabfitiseBreathingLoader: View {
    @Environment(ThemeManager.self) private var theme
    let title: String

    @State private var breathe = false

    init(title: String = "Loading...") {
        self.title = title
    }

    var body: some View {
        VStack(spacing: HabfitiseSpacing.lg) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(
                            theme.colors.accentGreen.opacity(0.22 - Double(ring) * 0.05),
                            lineWidth: 2
                        )
                        .frame(
                            width: 44 + CGFloat(ring) * 22,
                            height: 44 + CGFloat(ring) * 22
                        )
                        .scaleEffect(breathe ? 1.08 : 0.9)
                        .opacity(breathe ? 0.35 : 0.9)
                        .animation(
                            HabfitiseAnimation.breathe.delay(Double(ring) * 0.18),
                            value: breathe
                        )
                }

                Image("VayaLogo")
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 44, maxHeight: 44)
                    .scaleEffect(breathe ? 1.06 : 0.94)
                    .animation(HabfitiseAnimation.breathe, value: breathe)
            }
            .frame(width: 110, height: 110)

            Text(title)
                .font(HabfitiseTypography.callout)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .onAppear {
            breathe = true
        }
    }
}

// MARK: - Selection pulse ring

struct HabfitisePulseRing: View {
  @Environment(ThemeManager.self) private var theme
  let isActive: Bool

  @State private var pulse = false

  var body: some View {
    Circle()
      .stroke(theme.colors.accentGreen.opacity(pulse ? 0 : 0.45), lineWidth: 2)
      .scaleEffect(pulse ? 1.45 : 1)
      .opacity(isActive ? 1 : 0)
      .animation(isActive ? .easeOut(duration: 0.55) : .default, value: pulse)
      .onChange(of: isActive) { _, active in
        guard active else {
          pulse = false
          return
        }
        pulse = false
        withAnimation(.easeOut(duration: 0.55)) {
          pulse = true
        }
      }
  }
}

// MARK: - SwiftUI celebration burst

struct HabfitiseCelebrationBurst: View {
    @Environment(ThemeManager.self) private var theme

    private struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let symbol: String
        let delay: Double
    }

    private let particles: [Particle] = [
        ("star.fill", 0), ("bolt.fill", 0.04), ("heart.fill", 0.08),
        ("flame.fill", 0.02), ("figure.run", 0.06), ("trophy.fill", 0.1)
    ].enumerated().map { index, item in
        Particle(
            angle: Double(index) * 60 + Double.random(in: -12...12),
            distance: CGFloat.random(in: 56...96),
            size: CGFloat.random(in: 14...22),
            symbol: item.0,
            delay: item.1
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                ForEach(particles) { particle in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8)
                    let progress = min(max((elapsed - particle.delay) / 1.1, 0), 1)
                    let radians = particle.angle * .pi / 180

                    Image(systemName: particle.symbol)
                        .font(.system(size: particle.size, weight: .semibold))
                        .foregroundStyle(theme.colors.accentGreen)
                        .opacity(1 - progress)
                        .offset(
                            x: cos(radians) * particle.distance * progress,
                            y: sin(radians) * particle.distance * progress
                        )
                }
            }
        }
        .frame(width: 220, height: 220)
        .allowsHitTesting(false)
    }
}

// MARK: - Animated success mark

struct HabfitiseAnimatedSuccessMark: View {
    @Environment(ThemeManager.self) private var theme

    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0.8
    @State private var checkTrim: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.accentGreen.opacity(ringOpacity), lineWidth: 3)
                .frame(width: 92, height: 92)
                .scaleEffect(ringScale)

            Circle()
                .fill(theme.colors.accentGreen.opacity(0.12))
                .frame(width: 72, height: 72)

            CheckmarkShape()
                .trim(from: 0, to: checkTrim)
                .stroke(theme.colors.accentGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 34, height: 34)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                ringScale = 1
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.08)) {
                ringOpacity = 0
                ringScale = 1.18
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.15)) {
                checkTrim = 1
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.2))
        return path
    }
}
