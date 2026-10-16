// Plays the first 25 seconds of the "Just Do It" video on repeat while the
// morning alarm screen is up. The video plays from YouTube through the
// DO IT website's alarm-video page, with sound on even if the phone is on silent.
import SwiftUI
import WebKit
import AVFoundation

let alarmVideoURL = URL(string: "https://wonderbread4912.github.io/DO-IT/alarm-video.html")!

struct AlarmVideo: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        // Play sound even when the ring/silent switch is on silent.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: alarmVideoURL))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: ()) {
        view.loadHTMLString("", baseURL: nil) // stop the sound
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
