import SwiftUI

enum HabfitiseScrollCoordinateSpace {
    static let name = "habfitise-tab-scroll"
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named(HabfitiseScrollCoordinateSpace.name)).minY
                )
        }
    }
}

extension View {
    /// Attach to scroll content inside a tab screen. Reports offset to `TabBarState`.
    func reportScrollOffsetToTabBar() -> some View {
        modifier(ScrollOffsetReporterModifier())
    }

    /// Standard tab screen chrome: optional nav title + trailing sync dot.
    func habfitiseTabScreen(
        title: String? = nil,
        immersiveHeader: Bool = false
    ) -> some View {
        modifier(
            HabfitiseTabScreenModifier(
                title: title,
                immersiveHeader: immersiveHeader
            )
        )
    }

    /// Matches navigation bar to the current theme background (use on pushed screens).
    func habfitiseNavigationBar() -> some View {
        modifier(HabfitiseNavigationBarModifier())
    }
}

private struct ScrollOffsetReporterModifier: ViewModifier {
    @Environment(TabBarState.self) private var tabBarState

    func body(content: Content) -> some View {
        content
            .background(ScrollOffsetReader())
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                tabBarState.reportScrollOffset(-offset)
            }
    }
}

private struct HabfitiseTabScreenModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    @Environment(TabBarState.self) private var tabBarState
    let title: String?
    let immersiveHeader: Bool

    func body(content: Content) -> some View {
        NavigationStack {
            content
                .navigationTitle(title ?? "")
                .navigationBarTitleDisplayMode(title == nil ? .inline : .large)
                .toolbar {
                    if !AppConstants.Backend.useLocalOnly {
                        ToolbarItem(placement: .topBarTrailing) {
                            SyncStatusDot()
                        }
                    }
                }
                .toolbar(immersiveHeader ? .hidden : .visible, for: .navigationBar)
                .habfitiseNavigationBar()
        }
        .onAppear {
            tabBarState.resetScrollState()
        }
    }
}

private struct HabfitiseNavigationBarModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.preferredColorScheme, for: .navigationBar)
    }
}

/// Wrap scrollable tab content with coordinate space + bottom inset for the pill.
struct HabfitiseTabScrollContainer<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .reportScrollOffsetToTabBar()
                .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: HabfitiseScrollCoordinateSpace.name)
        .background(theme.colors.background.ignoresSafeArea())
    }
}

#if DEBUG
struct ScrollOffsetReporting_Previews: PreviewProvider {
    static var previews: some View {
        let tabBarState = TabBarState()

        return NavigationStack {
            HabfitiseTabScrollContainer {
                VStack(spacing: 16) {
                    ForEach(0..<20, id: \.self) { index in
                        Text("Row \(index)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .habfitiseTabScreen()
            .habfitiseGreenBackground()
        }
        .environment(tabBarState)
        .environment(SyncService())
            .environment(ThemeManager())
    }
}
#endif
