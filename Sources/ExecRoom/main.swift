import AppKit

// A menu-bar app (no Dock icon, see Info.plist's LSUIElement). Starting it starts the Exec Room and opens it in the
// browser; quitting it stops the Exec Room and every agent run.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
