import AppKit
import SwiftUI
import WebKit

struct ClawdStateView: NSViewRepresentable {
    private let resourceName: String
    private let mascotSet: MascotSet
    var reduceMotion = false

    init(status: SessionStatus, set: MascotSet = .classic, reduceMotion: Bool = false) {
        resourceName = status.resourceName
        mascotSet = set
        self.reduceMotion = reduceMotion
    }

    init(resourceName: String, set: MascotSet = .classic, reduceMotion: Bool = false) {
        self.resourceName = resourceName
        mascotSet = set
        self.reduceMotion = reduceMotion
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ClawdWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = ClawdWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ webView: ClawdWebView, context: Context) {
        let selectedResourceName = mascotSet == .clawdia
            ? resourceName.replacingOccurrences(of: "Clawd-", with: "Clawdia-")
            : resourceName
        let resourceKey = "\(selectedResourceName)-\(reduceMotion)"
        guard context.coordinator.loadedResource != resourceKey else { return }
        context.coordinator.loadedResource = resourceKey

        guard
            let url = Bundle.main.url(forResource: selectedResourceName, withExtension: "svg"),
            let source = try? String(contentsOf: url, encoding: .utf8)
        else { return }

        let focusedViewBox = resourceName == "Clawd-update"
            ? "viewBox=\"-7 -8 29 31\""
            : "viewBox=\"-3 -2 21 21\""
        let focusedSource = source.replacingOccurrences(
            of: "viewBox=\"-15 -25 45 45\"",
            with: focusedViewBox
        )
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; }
            svg { display: block; width: 100%; height: 100%; }
            \(reduceMotion ? "svg * { animation: none !important; }" : "")
          </style>
        </head>
        <body>\(focusedSource)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    final class Coordinator {
        var loadedResource: String?
    }
}

final class ClawdWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private extension SessionStatus {
    var resourceName: String {
        switch self {
        case .idle: "Clawd-idle"
        case .running: "Clawd-working"
        case .waiting: "Clawd-waiting"
        case .completed: "Clawd-completed"
        case .failed: "Clawd-failed"
        }
    }
}
