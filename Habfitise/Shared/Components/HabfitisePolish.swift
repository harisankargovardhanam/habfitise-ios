import SwiftUI
import UIKit

// MARK: - Animation

enum HabfitiseAnimation {
    static let interactive = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.8)
    static let card = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let tabTransition = Animation.easeInOut(duration: 0.2)
}

// MARK: - Haptics

enum HabfitiseHaptics {
    static func primaryButton() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func completion() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func milestone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func destructive() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Empty State

struct HabfitiseEmptyState: View {
    @Environment(ThemeManager.self) private var theme
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(theme.colors.accentGreen.opacity(0.4))
                .habfitiseFloating(amplitude: 8)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Skeleton

struct SkeletonRow: View {
    @Environment(ThemeManager.self) private var theme
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.colors.trackBackground)
            .frame(height: height)
            .habfitiseShimmer()
    }
}

struct WorkoutCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonRow(height: 22, cornerRadius: 6)
                .frame(width: 180)
            HStack(spacing: 8) {
                SkeletonRow(height: 28, cornerRadius: 14)
                    .frame(width: 90)
                SkeletonRow(height: 28, cornerRadius: 14)
                    .frame(width: 70)
                SkeletonRow(height: 28, cornerRadius: 14)
                    .frame(width: 100)
            }
            SkeletonRow(height: 52, cornerRadius: 14)
        }
    }
}

struct HabitListSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonRow(height: 120, cornerRadius: 14)
            }
        }
    }
}
