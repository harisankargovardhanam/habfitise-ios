import SwiftUI

struct HabfitiseChip: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .habfitiseChipStyle(
                    color: isSelected ? theme.colors.accentGreen : theme.colors.chipBackground,
                    textColor: isSelected ? theme.colors.textOnBackground : theme.colors.textPrimary
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }
}
