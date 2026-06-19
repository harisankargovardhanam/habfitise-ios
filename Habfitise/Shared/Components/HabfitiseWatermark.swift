import SwiftUI

struct HabfitiseWatermark: View {
    var body: some View {
        Text("HF")
            .font(.system(size: 140, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.07))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func habfitiseWatermark() -> some View {
        overlay(alignment: .topTrailing) {
            HabfitiseWatermark()
                .offset(x: 24, y: -20)
        }
    }
}
