import CoreGraphics
import Foundation

/// Human-readable count + label strings with correct pluralization.
enum HabfitiseCopy {
    static func plural(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        let pluralForm = plural ?? "\(singular)s"
        return count == 1 ? singular : pluralForm
    }

    static func counted(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        "\(count) \(Self.plural(count, singular, plural: plural))"
    }
}

enum HabfitiseSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}
