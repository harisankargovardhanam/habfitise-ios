import SwiftUI

/// Celebration player — SwiftUI vector animations (no Lottie dependency).
struct HabfitiseLottieView: View {
    let name: String
    var loopMode: CelebrationLoopMode = .playOnce
    var height: CGFloat = 160

    var body: some View {
        Group {
            switch name {
            case "success":
                HabfitiseAnimatedSuccessMark()
            default:
                HabfitiseAnimatedSuccessMark()
            }
        }
        .frame(height: height)
    }
}

enum CelebrationLoopMode {
    case playOnce
    case loop
}

/// Plays bundled celebration animation with SwiftUI fallback.
struct HabfitiseLottieOrFallback: View {
    let lottieName: String
    var loopMode: CelebrationLoopMode = .playOnce
    var height: CGFloat = 160
    @ViewBuilder let fallback: () -> AnyView

    init(
        lottieName: String,
        loopMode: CelebrationLoopMode = .playOnce,
        height: CGFloat = 160,
        @ViewBuilder fallback: @escaping () -> some View
    ) {
        self.lottieName = lottieName
        self.loopMode = loopMode
        self.height = height
        self.fallback = { AnyView(fallback()) }
    }

    var body: some View {
        HabfitiseLottieView(name: lottieName, loopMode: loopMode, height: height)
    }
}
