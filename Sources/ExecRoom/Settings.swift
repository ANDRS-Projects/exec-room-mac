import Foundation
import Security

/// Where the app keeps things, and the two choices it asks for at first start: the work folder (written into the
/// room's own settings file, which the room reads) and how agents are paid for (kept in the app's preferences; an API
/// key goes into the Mac's Keychain and only ever reaches the room as a setting it is started with).
enum Settings {
    /// HOME when it is set, as the room (Node) reads it, so both always look in the same Application Support folder.
    static let home = ProcessInfo.processInfo.environment["HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.homeDirectoryForCurrentUser
    /// The room's settings and data in app mode (ROOM_APP=1); the room uses the same folder.
    static let appDir = home.appendingPathComponent("Library/Application Support/Exec Room", isDirectory: true)
    static let configFile = appDir.appendingPathComponent("room.config.json")
    static let pidFile = appDir.appendingPathComponent("room.pid")
    static let logDir = home.appendingPathComponent("Library/Logs/Exec Room", isDirectory: true)
    static let logFile = logDir.appendingPathComponent("room.log")
    static let suggestedWorkFolder = home.appendingPathComponent("Documents/Exec Room", isDirectory: true)

    /// The room's port. 4179, as for a room started from a clone; `defaults write nu.andrs.exec-room port 4191`
    /// moves it (a clone and the app can't both use one port). Connect sign-ins remember the port they were made on.
    static var port: Int {
        let set = UserDefaults.standard.integer(forKey: "port")
        return (1024...65535).contains(set) ? set : 4179
    }

    static var roomURL: URL { URL(string: "http://127.0.0.1:\(port)/room.html")! }

    // MARK: The room's settings file

    /// The settings file as a JSON object; an empty one when it isn't there yet. Throws when it is there but isn't
    /// JSON, so a file the user edited by hand is never overwritten.
    static func readConfig() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: configFile) else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError("\(configFile.path) isn't a JSON object. Fix or remove it, then open Exec Room again.")
        }
        return object
    }

    static var workFolder: String? {
        (try? readConfig())?["workFolder"] as? String
    }

    /// Sets "workFolder" and keeps every other setting as it is.
    static func setWorkFolder(_ url: URL) throws {
        var config = try readConfig()
        config["workFolder"] = url.path
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: configFile, options: .atomic)
    }

    // MARK: Plan or key

    enum Billing: String { case plan, key }

    static var billing: Billing? {
        get { UserDefaults.standard.string(forKey: "billing").flatMap(Billing.init) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "billing") }
    }

    // MARK: The API key, in the Keychain

    private static let keyQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "Exec Room",
        kSecAttrAccount as String: "Anthropic API key",
    ]

    static func apiKey() -> String? {
        var query = keyQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveAPIKey(_ key: String) throws {
        SecItemDelete(keyQuery as CFDictionary)
        var add = keyQuery
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrLabel as String] = "Exec Room: Anthropic API key"
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError("The key couldn't be saved in the Keychain (\(SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)")).")
        }
    }

    static func deleteAPIKey() {
        SecItemDelete(keyQuery as CFDictionary)
    }
}

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
