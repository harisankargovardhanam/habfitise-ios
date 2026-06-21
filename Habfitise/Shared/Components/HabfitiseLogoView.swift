import SwiftUI

/// Brand mark from `HabfitiseLogo` asset (HF. on black). Always scales down to fit — never crops.
struct HabfitiseLogoView: View {
    var height: CGFloat = 40
    var maxWidth: CGFloat?

    var body: some View {
        Image("HabfitiseLogo")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(
                maxWidth: maxWidth,
                maxHeight: height
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Habfitise")
    }
}

#if DEBUG
struct HabfitiseLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            HabfitiseLogoView(height: 56, maxWidth: 200)
            HabfitiseLogoView(height: 40, maxWidth: 120)
        }
        .padding()
        .background(Color(hex: "#1A1A1A"))
    }
}
#endif
