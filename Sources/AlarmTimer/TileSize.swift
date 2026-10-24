import AppKit

/// How tall each countdown tile is. The caption and label stay the same size; the digits scale with the tile.
enum TileSize: String, MenuChoice {
    case small, medium, large

    static let defaultsKey = "tileSize"

    var title: String { rawValue.capitalized }

    /// Medium is 50% taller than Small, and Large twice as tall.
    var height: CGFloat {
        switch self {
        case .small: Self.smallHeight
        case .medium: Self.smallHeight * 1.5
        case .large: Self.smallHeight * 2
        }
    }
    private static let smallHeight: CGFloat = 84

    /// The saved choice, or Medium if nothing (or something unknown) is saved.
    static func current(in defaults: UserDefaults = .standard) -> TileSize {
        defaults.string(forKey: defaultsKey).flatMap(TileSize.init(rawValue:)) ?? .medium
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
