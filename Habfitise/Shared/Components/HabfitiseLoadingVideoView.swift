import AVFoundation
import SwiftUI

/// Looping splash video used on the app loading screen.
struct HabfitiseLoadingVideoView: View {
    var maxWidth: CGFloat = 280

    var body: some View {
        HabfitiseLoopingVideoPlayer(resourceName: "HabfitiseLoading", fileExtension: "mp4")
            .frame(maxWidth: maxWidth, maxHeight: maxWidth)
            .accessibilityLabel("Loading Habfitise")
    }
}

private struct HabfitiseLoopingVideoPlayer: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> HabfitisePlayerUIView {
        let view = HabfitisePlayerUIView()
        view.configure(resourceName: resourceName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: HabfitisePlayerUIView, context: Context) {}
}

private final class HabfitisePlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func configure(resourceName: String, fileExtension: String) {
        guard queuePlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player
        playerLayer.player = player
        player.play()
    }

    deinit {
        queuePlayer?.pause()
        playerLooper?.disableLooping()
    }
}

#if DEBUG
struct HabfitiseLoadingVideoView_Previews: PreviewProvider {
    static var previews: some View {
        HabfitiseLoadingVideoView()
            .padding()
            .background(Color.white)
    }
}
#endif
