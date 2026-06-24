import SwiftUI

/// Floating action above the tab bar — Apple Fitness–inspired food log entry.
struct FoodLogFloatingButton: View {
    let action: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .semibold))

                Text("Log Food")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF6723")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#FF6723").opacity(0.45), radius: 16, y: 8)
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
            }
        }
        .buttonStyle(HabfitiseScalePressButtonStyle(scale: 0.96))
        .accessibilityLabel("Log food")
        .accessibilityHint("Opens nutrition logging")
    }
}
