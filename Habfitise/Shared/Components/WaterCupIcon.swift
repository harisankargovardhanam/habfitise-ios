import SwiftUI

struct WaterCupIcon: View {
    @Environment(ThemeManager.self) private var theme
    var fillLevel: Double
    var size: CGFloat = 32

    private var clampedFill: Double {
        min(max(fillLevel, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: size * 0.7))
                .foregroundStyle(theme.colors.waterBlue.opacity(0.35))

            RoundedRectangle(cornerRadius: 2)
                .fill(theme.colors.waterBlue)
                .frame(width: size * 0.45, height: size * 0.55 * clampedFill)
                .offset(y: -size * 0.08)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: clampedFill)
        }
        .frame(width: size, height: size)
    }
}
