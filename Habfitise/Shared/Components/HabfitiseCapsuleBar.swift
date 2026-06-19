import SwiftUI

struct HabfitiseCapsuleBar: View {
    @Environment(ThemeManager.self) private var theme
    let value: Double
    let maxValue: Double
    var color: Color? = nil

    private var normalizedHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(min(max(value / maxValue, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer(minLength: 0)
                Capsule()
                    .fill(color ?? theme.colors.accentGreen)
                    .frame(height: max(geometry.size.height * normalizedHeight, 4))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: normalizedHeight)
            }
        }
    }
}
