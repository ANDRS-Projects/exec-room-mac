import AppKit

/// The menu-bar icon and its menu, and the two questions at first start (the work folder, then plan or API key).
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let room = Room()
    private var statusItem: NSStatusItem!
    private var openedThisLaunch = false
    private var quitting = false

    // MARK: Start-up

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "person.3.fill", accessibilityDescription: "Exec Room")
            button.setAccessibilityLabel("Exec Room")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        room.onChange = { [weak self] in self?.roomChanged() }
        room.onReady = { [weak self] in
            guard let self, !self.openedThisLaunch else { return }
            self.openedThisLaunch = true
            NSWorkspace.shared.open(Settings.roomURL)
        }

        // First start: both questions, in order. Cancelling either quits, since the room can't start without them.
        if Settings.workFolder == nil, !askWorkFolder(firstStart: true) { return NSApp.terminate(nil) }
        if Settings.billing == nil, !askBilling(firstStart: true) { return NSApp.terminate(nil) }
        startRoom()
    }

    private func startRoom() {
        room.start(billing: Settings.billing ?? .plan, apiKey: Settings.billing == .key ? Settings.apiKey() : nil)
    }

    /// Stops the room (and every agent run), does the change, and starts it again. Asks first while it runs.
    private func restart(_ what: String, change: @escaping () -> Bool) {
        if room.state == .running || room.state == .starting {
            let alert = NSAlert()
            alert.messageText = "Restart Exec Room to \(what)?"
            alert.informativeText = "Agents that are working right now stop. Your chats and drafts stay."
            alert.addButton(withTitle: "Restart")
            alert.addButton(withTitle: "Cancel")
            guard modal(alert) == .alertFirstButtonReturn else { return }
        }
        room.stop { [weak self] in
            guard let self else { return }
            if change() { self.openedThisLaunch = false }
            self.startRoom()
        }
    }

    // MARK: Quit

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard room.state == .running || room.state == .starting else { return .terminateNow }
        quitting = true
        roomChanged()
        room.stop { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabled(statusText))
        menu.addItem(.separator())

        let open = item("Open Exec Room", #selector(openRoom), key: "o")
        open.isEnabled = room.state == .running
        menu.addItem(open)
        switch room.state {
        case .stopped, .failed: menu.addItem(item("Start Exec Room", #selector(startAgain)))
        default: break
        }
        menu.addItem(item("Show Log", #selector(showLog)))
        menu.addItem(.separator())

        menu.addItem(disabled("Work folder: \(tilde(Settings.workFolder ?? "not chosen"))"))
        menu.addItem(item("Change Work Folder…", #selector(changeWorkFolder)))
        let pay = NSMenuItem(title: "Pay With", action: nil, keyEquivalent: "")
        let payMenu = NSMenu()
        let plan = item("Your Claude Plan", #selector(usePlan))
        plan.state = Settings.billing == .key ? .off : .on
        let key = item(Settings.apiKey() == nil ? "An API Key…" : "An API Key (Enter a New One…)", #selector(useKey))
        key.state = Settings.billing == .key ? .on : .off
        payMenu.addItem(plan)
        payMenu.addItem(key)
        if Settings.apiKey() != nil, Settings.billing != .key {
            payMenu.addItem(.separator())
            payMenu.addItem(item("Remove the Saved API Key", #selector(removeKey)))
        }
        pay.submenu = payMenu
        menu.addItem(pay)
        menu.addItem(.separator())
        menu.addItem(item("Quit Exec Room", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private var statusText: String {
        if quitting { return "Stopping agents and the Exec Room…" }
        switch room.state {
        case .stopped: return "Exec Room is stopped"
        case .starting: return "Exec Room is starting…"
        case .running: return Settings.billing == .key ? "Running, paid with your API key" : "Running on your Claude plan"
        case .failed: return "Exec Room stopped: see Show Log"
        }
    }

    private func roomChanged() {
        statusItem.button?.appearsDisabled = room.state != .running
        if case .failed(let why) = room.state, !quitting {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Exec Room couldn't start or stopped"
            alert.informativeText = why
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Show Log")
            if modal(alert) == .alertSecondButtonReturn { showLog() }
        }
    }

    @objc private func openRoom() { NSWorkspace.shared.open(Settings.roomURL) }
    @objc private func startAgain() { openedThisLaunch = false; startRoom() }
    @objc private func showLog() {
        if FileManager.default.fileExists(atPath: Settings.logFile.path) {
            NSWorkspace.shared.open(Settings.logFile)
        } else {
            NSWorkspace.shared.open(Settings.logDir)
        }
    }

    @objc private func changeWorkFolder() {
        guard askWorkFolder(firstStart: false) else { return }
        restart("use the new work folder") { true }
    }

    @objc private func usePlan() {
        guard Settings.billing == .key else { return }
        restart("pay with your Claude plan") { Settings.billing = .plan; return true }
    }

    @objc private func useKey() {
        guard askKey() else { return }
        restart("pay with your API key") { Settings.billing = .key; return true }
    }

    @objc private func removeKey() {
        let alert = NSAlert()
        alert.messageText = "Remove the saved API key?"
        alert.informativeText = "It is removed from your Mac's Keychain. Exec Room keeps running on your Claude plan."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        if modal(alert) == .alertFirstButtonReturn { Settings.deleteAPIKey() }
    }

    // MARK: The questions

    /// Asks where agents work. Returns false when cancelled. The room itself refuses folders it must not use
    /// (the home folder, ~/Library, its data folder) and says why; the obvious ones are caught here first.
    private func askWorkFolder(firstStart: Bool) -> Bool {
        while true {
            let alert = NSAlert()
            alert.messageText = firstStart ? "Where should agents work?" : "Choose a new work folder"
            alert.informativeText = """
            Agents start in this folder and save their drafts in its “drafts” folder. Every agent can read what is \
            in it, so pick a folder for Exec Room only.

            Suggested: \(tilde(Settings.suggestedWorkFolder.path))
            """
            alert.addButton(withTitle: "Use Documents/Exec Room")
            alert.addButton(withTitle: "Choose Another Folder…")
            alert.addButton(withTitle: firstStart ? "Quit" : "Cancel")
            let answer = modal(alert)
            var folder: URL
            if answer == .alertFirstButtonReturn {
                folder = Settings.suggestedWorkFolder
            } else if answer == .alertSecondButtonReturn {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.allowsMultipleSelection = false
                panel.prompt = "Use This Folder"
                panel.message = "Choose the folder agents work in. You can make a new one here."
                panel.directoryURL = Settings.home.appendingPathComponent("Documents")
                NSApp.activate(ignoringOtherApps: true)
                guard panel.runModal() == .OK, let chosen = panel.url else { continue }
                folder = chosen
            } else {
                return false
            }
            folder = folder.standardizedFileURL
            let path = folder.path
            let library = Settings.home.appendingPathComponent("Library").path
            if path == Settings.home.path || path == "/" || path == library || path.hasPrefix(library + "/") {
                let no = NSAlert()
                no.messageText = "Pick another folder"
                no.informativeText = "Agents can't work in your home folder or in Library: those hold your keys and settings."
                modal(no)
                continue
            }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Settings.setWorkFolder(folder)
                return true
            } catch {
                let failed = NSAlert(error: error)
                modal(failed)
                if firstStart { continue } else { return false }
            }
        }
    }

    /// Asks how agents are paid for. Returns false when cancelled.
    private func askBilling(firstStart: Bool) -> Bool {
        let alert = NSAlert()
        alert.messageText = "How should agents be paid for?"
        alert.informativeText = """
        Your Claude plan: agents run on the plan Claude Code is signed in to. If it isn't signed in yet, the room's \
        page has a “Sign in to Claude” button. Exec Room never sees your sign-in.

        An API key: pay per use with an Anthropic API key, with a spending limit per run and per day. The key is kept \
        in your Mac's Keychain.

        You can change this later in the menu bar, under Pay With.
        """
        alert.addButton(withTitle: "Use My Claude Plan")
        alert.addButton(withTitle: "Use an API Key…")
        alert.addButton(withTitle: firstStart ? "Quit" : "Cancel")
        switch modal(alert) {
        case .alertFirstButtonReturn:
            Settings.billing = .plan
            return true
        case .alertSecondButtonReturn:
            guard askKey() else { return askBilling(firstStart: firstStart) }
            Settings.billing = .key
            return true
        default:
            return false
        }
    }

    /// Asks for an API key and saves it in the Keychain. Returns false when cancelled.
    private func askKey() -> Bool {
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-ant-…"
        field.setAccessibilityLabel("Anthropic API key")
        while true {
            let alert = NSAlert()
            alert.messageText = "Enter your Anthropic API key"
            alert.informativeText = "Make one in the Claude Console under API Keys. It is saved in your Mac's Keychain and handed only to the agent runs."
            alert.accessoryView = field
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            guard modal(alert) == .alertFirstButtonReturn else { return false }
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.hasPrefix("sk-ant-"), key.count > 20, !key.contains(where: \.isWhitespace) else {
                let no = NSAlert()
                no.messageText = "That doesn't look like an Anthropic API key"
                no.informativeText = "Keys start with “sk-ant-”. Copy it again from the Claude Console."
                modal(no)
                continue
            }
            do {
                try Settings.saveAPIKey(key)
                return true
            } catch {
                modal(NSAlert(error: error))
                return false
            }
        }
    }

    // MARK: Helpers

    @discardableResult
    private func modal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func tilde(_ path: String) -> String {
        path.hasPrefix(Settings.home.path + "/") ? "~" + path.dropFirst(Settings.home.path.count) : path
    }
}
