import AppKit

@main
@MainActor
enum App {
    static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(runSelfTest() ? 0 : 1)
        }

        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
