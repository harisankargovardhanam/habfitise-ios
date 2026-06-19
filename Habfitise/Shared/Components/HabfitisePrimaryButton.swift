import SwiftUI

struct HabfitisePrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(HabfitisePrimaryButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}
