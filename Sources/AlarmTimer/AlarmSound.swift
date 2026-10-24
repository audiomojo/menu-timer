import AppKit

/// The sound a finished timer rings with. Raw values are the macOS system sound names.
enum AlarmSound: String, MenuChoice {
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
