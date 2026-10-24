import AppKit

/// The sound a finished timer rings with. Raw values are the macOS system sound names.
enum AlarmSound: String, CaseIterable {
    case chime = "Glass"
    case ping = "Ping"
    case fanfare = "Hero"
    case sonar = "Submarine"
    case telegraph = "Morse"
    case marimba = "Sosumi"
    case bubble = "Pop"
    case lightTap = "Tink"
    case whoosh = "Blow"
    case croak = "Frog"

    static let defaultsKey = "alarmSound"

    var title: String {
        switch self {
        case .chime: "Chime"
        case .ping: "Ping"
        case .fanfare: "Fanfare"
        case .sonar: "Sonar"
        case .telegraph: "Telegraph"
        case .marimba: "Marimba"
        case .bubble: "Bubble"
        case .lightTap: "Light Tap"
        case .whoosh: "Whoosh"
        case .croak: "Croak"
        }
    }

    /// The saved choice, or Chime if nothing (or something unknown) is saved.
    static func current(in defaults: UserDefaults = .standard) -> AlarmSound {
        defaults.string(forKey: defaultsKey).flatMap(AlarmSound.init(rawValue:)) ?? .chime
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }

    func play() {
        if let sound = NSSound(named: rawValue) {
            sound.stop()  // restart if it's still playing from the last ring or preview
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

/// Builds the "Sound" submenu: one checkmarked item per sound; choosing one saves it and plays a preview.
@MainActor
final class SoundMenuController: NSObject, NSMenuDelegate {
    func makeItem() -> NSMenuItem {
        let menu = NSMenu(title: "Sound")
        menu.delegate = self
        for sound in AlarmSound.allCases {
            let item = menu.addItem(withTitle: sound.title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sound
        }
        let item = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let current = AlarmSound.current()
        for item in menu.items {
            item.state = item.representedObject as? AlarmSound == current ? .on : .off
        }
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard let sound = item.representedObject as? AlarmSound else { return }
        sound.save()
        sound.play()
    }
}
