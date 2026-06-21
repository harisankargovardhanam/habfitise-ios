import Foundation
import Observation
import SwiftUI

enum TabBarLayout {
    /// Scroll content inset so the floating pill does not cover the last section.
    static let floatingClearance: CGFloat = 136

    static let edgeInset: CGFloat = 20
    static let capsulePadding: CGFloat = 8
    static let tabSpacing: CGFloat = 8
    static let tabSpacingCompact: CGFloat = 6

    static let iconSize: CGFloat = 20
    static let iconSizeCompact: CGFloat = 18
    static let labelSize: CGFloat = 14

    static let itemPaddingHActive: CGFloat = 18
    static let itemPaddingHInactive: CGFloat = 15
    static let itemPaddingHActiveCompact: CGFloat = 14
    static let itemPaddingHInactiveCompact: CGFloat = 12
    static let itemPaddingV: CGFloat = 14
    static let itemPaddingVCompact: CGFloat = 12
}

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case habits
    case tasks
    case workout
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .habits: "Habits"
        case .tasks: "Tasks"
        case .workout: "Workout"
        case .progress: "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .habits: "leaf.fill"
        case .tasks: "checklist"
        case .workout: "dumbbell.fill"
        case .progress: "chart.bar.fill"
        }
    }
}

@Observable
@MainActor
final class TabBarState {
    var activeTab: MainTab = .home
    var isVisible = true
    var scrollOffset: CGFloat = 0
    var tabTransitionForward = true

    private var lastScrollOffset: CGFloat = 0
    private var scrollStopTask: Task<Void, Never>?

    /// Full-width pill with labels when true; compact icon-only pill when false.
    var showsLabels: Bool { isVisible }

    var labelOpacity: Double {
        guard scrollOffset > 20 else { return 1 }
        let progress = min((scrollOffset - 20) / 36, 1)
        return 1 - progress
    }

    var pillMaxWidth: CGFloat? {
        isVisible ? nil : 220
    }

    func selectTab(_ tab: MainTab) {
        guard activeTab != tab else { return }
        let currentIndex = MainTab.allCases.firstIndex(of: activeTab) ?? 0
        let nextIndex = MainTab.allCases.firstIndex(of: tab) ?? 0
        tabTransitionForward = nextIndex > currentIndex
        withAnimation(HabfitiseAnimation.tabTransition) {
            activeTab = tab
            isVisible = true
        }
    }

    func reportScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset

        let delta = offset - lastScrollOffset
        if delta > 1, offset > 20 {
            setCompact(true)
        } else if delta < -1 {
            setCompact(false)
        }

        lastScrollOffset = offset
        scheduleScrollStopRestore()
    }

    func resetScrollState() {
        lastScrollOffset = 0
        scrollOffset = 0
        isVisible = true
        scrollStopTask?.cancel()
    }

    private func setCompact(_ compact: Bool) {
        guard isVisible == !compact else { return }
        withAnimation(HabfitiseAnimation.tabTransition) {
            isVisible = !compact
        }
    }

    private func scheduleScrollStopRestore() {
        scrollStopTask?.cancel()
        scrollStopTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(HabfitiseAnimation.tabTransition) {
                isVisible = true
            }
        }
    }
}
