import ServiceManagement

/// Opening the app at login, so saved timers pick up again after a restart.
@MainActor
enum LoginItem {
    private static let offeredKey = "loginItemOffered"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Couldn't change Open at Login: \(error.localizedDescription)")
        }
    }

    /// Turns it on the first time the app runs; after that it's whatever the user chose in the menu.
    static func enableOnFirstLaunch(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: offeredKey) else { return }
        defaults.set(true, forKey: offeredKey)
        setEnabled(true)
    }
}
