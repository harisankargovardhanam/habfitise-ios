import Foundation
import Observation
import SwiftUI

enum TabBarLayout {
    /// Breathing room between the last scroll item and the tab bar.
    static let scrollBreathingRoom: CGFloat = 16

    /// How far the bar slides off-screen when hidden.
    static let hideOffset: CGFloat = 110

    /// Gap between the bar and the bottom safe area (floats lower on screen).
    static let floatingBottomInset: CGFloat = 2

    /// Home-indicator clearance below the pill (overlay does not auto-inset scroll content).
    static let homeIndicatorReserve: CGFloat = 34

    /// Full scroll inset so the last row clears the floating tab bar at rest.
    static var tabBarScrollInset: CGFloat {
        barHeight + floatingBottomInset + homeIndicatorReserve + scrollBreathingRoom
    }

    /// Legacy alias used by tab scroll views.
    static var floatingClearance: CGFloat { tabBarScrollInset }

    static var barHeight: CGFloat {
        itemSize + capsulePadding * 2
    }

    static let edgeInset: CGFloat = 24
    static let capsulePadding: CGFloat = 10
    static let tabSpacing: CGFloat = 4
    static let tabSpacingCompact: CGFloat = 2

    static let iconSize: CGFloat = 22
    static let iconSizeCompact: CGFloat = 20

    /// Active selection pill — wide squircle like reference tab bars.
    static let activePillWidth: CGFloat = 58
    static let activePillHeight: CGFloat = 40
    static let activePillWidthCompact: CGFloat = 52
    static let activePillHeightCompact: CGFloat = 36

    static let itemSize: CGFloat = 58
    static let itemSizeCompact: CGFloat = 52
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

    private var lastScrollOffset: CGFloat = 0
    private var hasEstablishedBaseline = false
    private var suppressHideUntil: Date?

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
        activeTab = tab
        resetScrollState()
    }

    func reportScrollOffset(_ offset: CGFloat) {
        if let until = suppressHideUntil, Date() < until {
            lastScrollOffset = offset
            scrollOffset = offset
            return
        }
        suppressHideUntil = nil

        if !hasEstablishedBaseline {
            lastScrollOffset = offset
            scrollOffset = offset
            hasEstablishedBaseline = true
            return
        }

        let delta = offset - lastScrollOffset

        // Ignore large layout jumps (List/ScrollView mount, tab switch, content reflow).
        guard abs(delta) < 120 else {
            lastScrollOffset = offset
            scrollOffset = offset
            return
        }

        if offset <= 12 {
            if !isVisible { isVisible = true }
        } else if delta > 8, offset > 36 {
            isVisible = false
        } else if delta < -8 {
            isVisible = true
        }

        lastScrollOffset = offset
        scrollOffset = offset
    }

    func resetScrollState() {
        lastScrollOffset = 0
        scrollOffset = 0
        isVisible = true
        hasEstablishedBaseline = false
        suppressHideUntil = Date().addingTimeInterval(0.45)
    }
}
