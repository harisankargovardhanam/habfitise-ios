import SwiftUI

enum HabfitiseTypography {
    // MARK: - Text

    static let largeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
    static let title: Font = .system(size: 28, weight: .semibold, design: .rounded)
    static let title2: Font = .system(size: 22, weight: .semibold, design: .rounded)
    static let headline: Font = .system(size: 17, weight: .semibold, design: .rounded)
    static let body: Font = .system(size: 17, weight: .regular, design: .rounded)
    static let callout: Font = .system(size: 16, weight: .regular, design: .rounded)
    static let subheadline: Font = .system(size: 15, weight: .regular, design: .rounded)
    static let footnote: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let caption: Font = .system(size: 13, weight: .medium, design: .rounded)
    static let sectionLabel: Font = .system(size: 11, weight: .semibold, design: .rounded)
    static let button: Font = .system(size: 17, weight: .semibold, design: .rounded)

    // MARK: - Numeric (monospacedDigit)

    static let numericLargeTitle: Font = .system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
    static let numericTitle: Font = .system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
    static let numericTitle2: Font = .system(size: 22, weight: .semibold, design: .rounded).monospacedDigit()
    static let numericHeadline: Font = .system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
    static let numericBody: Font = .system(size: 17, weight: .regular, design: .rounded).monospacedDigit()
    static let numericCallout: Font = .system(size: 16, weight: .regular, design: .rounded).monospacedDigit()
    static let numericSubheadline: Font = .system(size: 15, weight: .regular, design: .rounded).monospacedDigit()
    static let numericFootnote: Font = .system(size: 13, weight: .regular, design: .rounded).monospacedDigit()
    static let numericCaption: Font = .system(size: 13, weight: .medium, design: .rounded).monospacedDigit()
    static let numericStat: Font = .system(size: 40, weight: .bold, design: .rounded).monospacedDigit()
    static let numericPercentage: Font = .system(size: 24, weight: .bold, design: .rounded).monospacedDigit()
}
