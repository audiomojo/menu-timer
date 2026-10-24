import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TimerModel()
    private var statusItem: NSStatusItem!
    private var windowController: TimerWindowController!
    private let soundMenu = ChoiceMenuController<AlarmSound>(title: "Sound") { $0.play() }
    private lazy var tileSizeMenu = ChoiceMenuController<TileSize>(title: "Tile Size") { [weak self] size in
        self?.windowController.tileSize = size
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        LoginItem.enableOnFirstLaunch()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Alarm Timer")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        windowController = TimerWindowController(model: model)
        // Right-clicking the window offers the settings too.
        let windowMenu = NSMenu()
        windowMenu.addItem(soundMenu.makeItem())
        windowMenu.addItem(tileSizeMenu.makeItem())
        windowController.panel.contextMenu = windowMenu
        model.onUpdate = { [weak self] in self?.refresh() }
        model.onFire = { [weak self] in self?.windowController.show() }
        refresh()
        windowController.show()
    }

    private func refresh() {
        // The menu bar shows whichever timer finishes first.
        statusItem.button?.title = model.soonestRemaining.map(formatCountdown) ?? ""
        windowController.refresh()
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            windowController.toggle()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let stop = menu.addItem(withTitle: "Stop All", action: #selector(stopAll), keyEquivalent: "")
        stop.target = self
        stop.isEnabled = !model.timers.isEmpty
        menu.autoenablesItems = false
        menu.addItem(.separator())
        menu.addItem(soundMenu.makeItem())
        menu.addItem(tileSizeMenu.makeItem())
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Alarm Timer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Attach the menu only for this click so left-click keeps toggling the window.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleOpenAtLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func stopAll() {
        model.removeAll()
    }

    /// An accessory app shows no menu bar, but the key equivalents (⌘V, ⌘W, ⌘Q…) still route through it.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Alarm Timer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = fileMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = editMenu

        return main
    }
}
