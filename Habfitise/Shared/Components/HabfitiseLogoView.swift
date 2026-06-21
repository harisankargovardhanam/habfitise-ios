import SwiftUI

/// Brand wordmark from `HabfitiseLogo` asset — preserves green "fit" accent.
struct HabfitiseLogoView: View {
    var height: CGFloat = 32

    var body: some View {
        Image("HabfitiseLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Habfitise")
    }
}

#if DEBUG
struct HabfitiseLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            HabfitiseLogoView(height: 28)
            HabfitiseLogoView(height: 40)
        }
        .padding()
    }
}
#endif
