import Darwin
import Foundation

/// The Exec Room server: started with the app's own Node from inside the app, in app mode (ROOM_APP=1), and stopped
/// with SIGTERM, which makes the room stop every agent run before it exits. Its output goes to
/// ~/Library/Logs/Exec Room/room.log; the last lines are kept for the menu and for an alert when it stops by itself.
final class Room {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    private(set) var state: State = .stopped { didSet { onChange?() } }
    var onChange: (() -> Void)?
    /// Called once the page answers, the first time after each start.
    var onReady: (() -> Void)?

    private var process: Process?
    private var stopping: (() -> Void)?
    private var lastLines: [String] = []
    private var partial = ""
    private let queue = DispatchQueue(label: "room.output")

    /// The program and the code inside the app: Contents/Resources/node/bin/node and Contents/Resources/exec-room.
    static var node: URL? { Bundle.main.resourceURL?.appendingPathComponent("node/bin/node") }
    static var code: URL? { Bundle.main.resourceURL?.appendingPathComponent("exec-room", isDirectory: true) }

    // MARK: Start

    func start(billing: Settings.Billing, apiKey: String?) {
        guard process == nil else { return }
        guard let node = Self.node, let code = Self.code,
              FileManager.default.isExecutableFile(atPath: node.path),
              FileManager.default.fileExists(atPath: code.appendingPathComponent("room-server.js").path) else {
            state = .failed("This copy of the app is incomplete (Node or the Exec Room's code is missing). Download it again.")
            return
        }
        Self.stopLeftover()

        var env = ProcessInfo.processInfo.environment
        // Settings that would point the room elsewhere, or pay for it differently, come only from the app.
        for name in ["ROOM_CONFIG_FILE", "ROOM_DATA_DIR", "ROOM_WORK_DIR", "ROOM_AUTH", "ROOM_ANTHROPIC_API_KEY",
                     "ROOM_ANTHROPIC_API_KEY_REF", "ANTHROPIC_API_KEY", "PORT"] {
            env.removeValue(forKey: name)
        }
        env["ROOM_APP"] = "1"
        env["PORT"] = String(Settings.port)
        // Claude Code finds its sign-in in the Keychain by the user's name; Finder always sets it, a bare launch may not.
        if env["USER"] == nil { env["USER"] = NSUserName() }
        if env["LOGNAME"] == nil { env["LOGNAME"] = NSUserName() }
        if billing == .key {
            guard let apiKey, !apiKey.isEmpty else {
                state = .failed("No API key is saved. Choose “Pay With” in the menu to enter one, or use your Claude plan.")
                return
            }
            env["ROOM_AUTH"] = "api-key"
            env["ROOM_ANTHROPIC_API_KEY"] = apiKey
        }

        let log: FileHandle
        do {
            log = try Self.openLog()
        } catch {
            state = .failed("Couldn't write the log in \(Settings.logDir.path): \(error.localizedDescription)")
            return
        }

        let p = Process()
        p.executableURL = node
        p.arguments = ["room-server.js"]
        p.currentDirectoryURL = code
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        lastLines = []
        partial = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            log.write(data)
            self?.queue.sync { self?.keep(data) }
        }
        p.terminationHandler = { [weak self] done in
            DispatchQueue.main.async { self?.ended(done, log: log) }
        }
        do {
            try p.run()
        } catch {
            state = .failed("Couldn't start the Exec Room: \(error.localizedDescription)")
            return
        }
        process = p
        try? String(p.processIdentifier).write(to: Settings.pidFile, atomically: true, encoding: .utf8)
        state = .starting
        waitUntilReady(p)
    }

    /// Polls the page until it answers, for as long as the server is running (start-up may wait on 1Password).
    private func waitUntilReady(_ p: Process) {
        var request = URLRequest(url: Settings.roomURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                guard let self, self.process === p, p.isRunning else { return }
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    self.state = .running
                    self.onReady?()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.waitUntilReady(p) }
                }
            }
        }.resume()
    }

    private func ended(_ p: Process, log: FileHandle) {
        try? log.close()
        try? FileManager.default.removeItem(at: Settings.pidFile)
        process = nil
        if let done = stopping {
            stopping = nil
            state = .stopped
            done()
            return
        }
        // It stopped by itself: the room says why in its last lines (a work folder it refuses, a port in use, …).
        let why = queue.sync { lastLines.suffix(6).joined(separator: "\n") }
        state = .failed(why.isEmpty ? "The Exec Room stopped (exit code \(p.terminationStatus))." : why)
    }

    // MARK: Stop

    /// SIGTERM: the room stops every agent run (it waits up to 5 seconds for them) and exits. After 10 seconds it is
    /// killed, so Quit never leaves anything running.
    func stop(then done: @escaping () -> Void) {
        guard let p = process, p.isRunning else { state = .stopped; done(); return }
        stopping = done
        p.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        }
    }

    /// A room the app started before and didn't stop (the app crashed or was force-quit): stopped before a new start,
    /// so it doesn't keep running unseen. Only a process running this app's own Node is touched.
    static func stopLeftover() {
        guard let text = try? String(contentsOf: Settings.pidFile, encoding: .utf8),
              let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1 else { return }
        defer { try? FileManager.default.removeItem(at: Settings.pidFile) }
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0,
              let node = node?.resolvingSymlinksInPath().path,
              URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath().path == node else { return }
        kill(pid, SIGTERM)
        for _ in 0..<100 where kill(pid, 0) == 0 { usleep(100_000) }
        if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
    }

    // MARK: Output

    private func keep(_ data: Data) {
        partial += String(decoding: data, as: UTF8.self)
        var lines = partial.components(separatedBy: "\n")
        partial = lines.removeLast()
        lastLines.append(contentsOf: lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        if lastLines.count > 40 { lastLines.removeFirst(lastLines.count - 40) }
    }

    /// room.log for this start; the previous start's log is kept as room.previous.log.
    private static func openLog() throws -> FileHandle {
        let fm = FileManager.default
        try fm.createDirectory(at: Settings.logDir, withIntermediateDirectories: true)
        let previous = Settings.logDir.appendingPathComponent("room.previous.log")
        if fm.fileExists(atPath: Settings.logFile.path) {
            try? fm.removeItem(at: previous)
            try? fm.moveItem(at: Settings.logFile, to: previous)
        }
        fm.createFile(atPath: Settings.logFile.path, contents: nil, attributes: [.posixPermissions: 0o600])
        return try FileHandle(forWritingTo: Settings.logFile)
    }
}
