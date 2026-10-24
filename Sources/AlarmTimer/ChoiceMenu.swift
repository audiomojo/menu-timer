import AppKit

/// A setting picked from a submenu, saved in the user defaults.
protocol MenuChoice: CaseIterable, Equatable where AllCases == [Self] {
    var title: String { get }
    static func current(in defaults: UserDefaults) -> Self
    func save(in defaults: UserDefaults)
}

/// Builds a submenu with one checkmarked item per choice; picking one saves it and calls `onChoose`.
@MainActor
final class ChoiceMenuController<Choice: MenuChoice>: NSObject, NSMenuDelegate {
    private let title: String
    private let onChoose: (Choice) -> Void

    init(title: String, onChoose: @escaping (Choice) -> Void = { _ in }) {
        self.title = title
        self.onChoose = onChoose
    }

    func makeItem() -> NSMenuItem {
        let menu = NSMenu(title: title)
        menu.delegate = self
        for (index, choice) in Choice.allCases.enumerated() {
            let item = menu.addItem(withTitle: choice.title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let current = Choice.current(in: .standard)
        for item in menu.items {
            item.state = Choice.allCases[item.tag] == current ? .on : .off
        }
    }

    @objc private func choose(_ item: NSMenuItem) {
        let choice = Choice.allCases[item.tag]
        choice.save(in: .standard)
        onChoose(choice)
    }
}
