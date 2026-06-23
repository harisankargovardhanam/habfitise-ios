import SwiftUI

// MARK: - Tumbler glass shape

struct WaterGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let centerX = width / 2

        let topY = height * 0.05
        let bottomY = height * 0.93
        let topHalfWidth = width * 0.44
        let bottomHalfWidth = width * 0.34

        path.move(to: CGPoint(x: centerX - topHalfWidth, y: topY))
        path.addLine(to: CGPoint(x: centerX - bottomHalfWidth, y: bottomY - width * 0.1))
        path.addQuadCurve(
            to: CGPoint(x: centerX + bottomHalfWidth, y: bottomY - width * 0.1),
            control: CGPoint(x: centerX, y: bottomY)
        )
        path.addLine(to: CGPoint(x: centerX + topHalfWidth, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: centerX - topHalfWidth, y: topY),
            control: CGPoint(x: centerX, y: topY - width * 0.08)
        )
        return path
    }
}

// MARK: - Icon (filled / empty / partial)

struct WaterGlassIcon: View {
    @Environment(ThemeManager.self) private var theme

    var isFilled: Bool = true
    var fillLevel: Double?
    var size: CGFloat = 16
    var filledColor: Color?
    var emptyColor: Color?

    private var level: Double {
        if let fillLevel {
            return min(max(fillLevel, 0), 1)
        }
        return isFilled ? 1 : 0
    }

    private var activeColor: Color {
        filledColor ?? theme.colors.waterBlue
    }

    private var inactiveColor: Color {
        emptyColor ?? theme.colors.trackBackground
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            WaterGlassShape()
                .fill(inactiveColor.opacity(level > 0 ? 0.2 : 0.35))

            if level > 0 {
                WaterGlassShape()
                    .fill(activeColor)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: size * 0.84 * level)
                    }
            }

            WaterGlassShape()
                .stroke(
                    level > 0 ? activeColor.opacity(0.85) : inactiveColor.opacity(0.55),
                    lineWidth: max(1, size * 0.07)
                )
        }
        .frame(width: size * 0.72, height: size)
    }
}

// MARK: - Large animated glass (water logging screen)

struct WaterCupIcon: View {
    @Environment(ThemeManager.self) private var theme
    var fillLevel: Double
    var size: CGFloat = 32

    private var clampedFill: Double {
        min(max(fillLevel, 0), 1)
    }

    var body: some View {
        WaterGlassIcon(fillLevel: clampedFill, size: size)
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: clampedFill)
    }
}
