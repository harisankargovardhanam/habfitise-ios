import SwiftUI

struct HabfitiseSectionLabel: View {
    @Environment(ThemeManager.self) private var theme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(HabfitiseTypography.sectionLabel)
            .tracking(1.2)
            .foregroundStyle(theme.colors.textTertiary)
    }
}
