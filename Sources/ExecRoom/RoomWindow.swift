import AppKit
import WebKit

/// The room's own window: the room's page in WebKit (Safari's engine), without tabs or an address bar. Only the
/// room's own address is shown here; every other link (a Connect sign-in, a Notion page, GitHub, a mail draft) goes to
/// the browser or the mail app, where sign-ins and extensions work. A Connect sign-in finished in the browser shows up
/// here by itself: the page asks the room, not the tab. Closing the window leaves the room running.
final class RoomWindow: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?

    var isOpen: Bool { window?.isVisible == true }

    /// Shows the window (making it the first time) and loads the room, or brings it to the front.
    func show(reload: Bool = false) {
        if window == nil { make() }
        if reload || webView?.url == nil { load() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func load() {
        webView?.load(URLRequest(url: Settings.roomURL))
    }

    func reload() { webView?.reload() }

    func zoom(by step: Double?) {
        guard let webView else { return }
        webView.pageZoom = step.map { min(3, max(0.5, webView.pageZoom + $0)) } ?? 1
    }

    private func make() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // the page's own settings (theme, open panels) are kept between starts
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.setAccessibilityLabel("Exec Room")
        webView = web

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 820),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Exec Room"
        w.contentView = web
        w.minSize = NSSize(width: 480, height: 400)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        w.setFrameAutosaveName("Exec Room")  // reopens where it was
        window = w
    }

    private func isRoom(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "http" && (url.host == "127.0.0.1" || url.host == "localhost") && url.port == Settings.port
    }

    /// Anything that isn't the room goes to the Mac: https to the browser, mailto to the mail app.
    private func openOutside(_ url: URL?) {
        guard let url, let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = action.request.url
        if isRoom(url) || url?.scheme == "about" || url?.scheme == "blob" || url?.scheme == "data" {
            decisionHandler(.allow)
        } else {
            openOutside(url)
            decisionHandler(.cancel)
        }
    }

    // MARK: WKUIDelegate

    /// target="_blank" and window.open: a new tab in the browser, never a window here.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if isRoom(action.request.url) { webView.load(action.request) } else { openOutside(action.request.url) }
        return nil
    }

    /// "Attach file": the Mac's file chooser.
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        guard let window else { completionHandler(panel.runModal() == .OK ? panel.urls : nil); return }
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}
