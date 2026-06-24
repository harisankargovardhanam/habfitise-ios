import Foundation
import Observation
import SwiftUI

enum TabBarLayout {
    /// Breathing room between the last scroll item and the tab bar.
    static let scrollBreathingRoom: CGFloat = 16

    /// How far the bar slides off-screen when hidden.
    static let hideOffset: CGFloat = 120

    /// Gap between the bar and the bottom safe area.
    static let floatingBottomInset: CGFloat = 6

    /// Home-indicator clearance below the pill.
    static let homeIndicatorReserve: CGFloat = 28

    /// Reserve space for the floating food log button above the tab bar.
    static let foodLogButtonHeight: CGFloat = 48
    static let foodLogButtonSpacing: CGFloat = 10

    static var foodLogButtonClearance: CGFloat {
        foodLogButtonHeight + foodLogButtonSpacing
    }

    /// Full scroll inset so the last row clears the floating tab bar at rest.
    static var tabBarScrollInset: CGFloat {
        barHeight + floatingBottomInset + homeIndicatorReserve + scrollBreathingRoom
    }

    /// Full scroll inset including food log FAB + tab bar.
    static var tabBarScrollInsetWithFoodLog: CGFloat {
        tabBarScrollInset + foodLogButtonClearance
    }

    static var floatingClearance: CGFloat { tabBarScrollInset }

    static var barHeight: CGFloat {
        tabItemHeight + capsulePadding * 2
    }

    /// Horizontal inset — bar floats wide like reference tab bars.
    static let edgeInset: CGFloat = 16
    static let capsulePadding: CGFloat = 8
    static let tabSpacing: CGFloat = 2

    static let iconSize: CGFloat = 20
    static let labelSize: CGFloat = 10
    static let tabItemHeight: CGFloat = 46
    static let activePillHeight: CGFloat = 46
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
        filledSystemImage
    }

    var filledSystemImage: String {
        switch self {
        case .home: "house.fill"
        case .habits: "leaf.fill"
        case .tasks: "checklist"
        case .workout: "dumbbell.fill"
        case .progress: "chart.bar.fill"
        }
    }

    var outlineSystemImage: String {
        switch self {
        case .home: "house"
        case .habits: "leaf"
        case .tasks: "checklist"
        case .workout: "dumbbell"
        case .progress: "chart.bar"
        }
    }

    var shortTitle: String {
        switch self {
        case .home: "Home"
        case .habits: "Habits"
        case .tasks: "Tasks"
        case .workout: "Workout"
        case .progress: "Progress"
        }
    }
}

@Observable
@MainActor
final class TabBarState {
    var activeTab: MainTab = .home
    var isVisible = true
    var scrollOffset: CGFloat = 0
    var showsFoodLog = false
    var foodLogStartsOnAdd = false

    private var lastScrollOffset: CGFloat = 0
    private var hasEstablishedBaseline = false
    private var suppressHideUntil: Date?

    /// Full-width pill with labels when true; compact icon-only pill when false.
    var showsLabels: Bool { isVisible }

    var labelOpacity: Double { 1 }

    func openFoodLog(addNew: Bool = false) {
        foodLogStartsOnAdd = addNew
        showsFoodLog = true
        isVisible = true
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
