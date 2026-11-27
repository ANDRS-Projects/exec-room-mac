// swift-tools-version:5.9
// Exec Room for Mac: a menu-bar app that starts the Exec Room (github.com/ANDRS-Projects/exec-room) with its own
// Node and opens it in the browser. scripts/build-app.sh turns the built program into "Exec Room.app".
import PackageDescription

let package = Package(
    name: "ExecRoom",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ExecRoom", path: "Sources/ExecRoom")
    ]
)
