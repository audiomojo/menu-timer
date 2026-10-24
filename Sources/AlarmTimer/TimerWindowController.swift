import AppKit

/// The floating window: one row per running timer, plus the entry field and Start button.
@MainActor
final class TimerWindowController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let panel: ClickReportingPanel
    private let model: TimerModel
    private let rowsStack = NSStackView()
    /// Placeholder shown when no timers are running.
    private let idleRow = TimerRowView(showsStop: false)
    private var rows: [UUID: TimerRowView] = [:]
    private var rowIDs: [UUID] = []
    /// True while a droppable meeting is dragged over the window; every tile is outlined.
    private var isDropTarget = false {
        didSet { allRows.forEach { $0.isDropTarget = isDropTarget } }
    }
    private var allRows: [TimerRowView] { [idleRow] + rows.values }

    var tileSize: TileSize {
        didSet {
            allRows.forEach { $0.tileHeight = tileSize.height }
            fitHeight()
        }
    }
    private let field = NSTextField()
    private let startButton = NSButton(title: "Start", target: nil, action: nil)

    private let rowSpacing: CGFloat = 6
    private let frameDefaultsKey = "panelFrame"
    /// True while we position the panel ourselves, so only user moves and resizes get saved.
    private var isPlacing = false

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    /// For alarms on another day, e.g. a meeting dragged in from later in the week: "Fri 9:30 AM".
    private let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEjmm")
        return formatter
    }()

    init(model: TimerModel, tileSize: TileSize = .current()) {
        self.model = model
        self.tileSize = tileSize
        panel = ClickReportingPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
                                    styleMask: [.titled, .closable, .resizable],
                                    backing: .buffered, defer: false)
        super.init()

        configurePanel()
        configureIdleRow()
        panel.contentView = makeContent()
        refresh()
        updateStartButton()
        restoreFrame()
        panel.delegate = self
    }

    // MARK: Setup

    private func configurePanel() {
        panel.title = "Alarm / Timer"
        // Any click in the window silences (and clears) the timers that are ringing.
        panel.onMouseDown = { [weak self] in
            guard let self, self.model.isRinging else { return }
            self.model.removeRinging()
        }
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func configureIdleRow() {
        idleRow.tileHeight = tileSize.height
        idleRow.caption.stringValue = "Enter a Duration or Time"
        idleRow.countdown.text = formatCountdown(0)
        idleRow.countdown.color = .tertiaryLabelColor
    }

    private func makeContent() -> NSView {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .centerX
        rowsStack.spacing = rowSpacing

        let bottomBar = makeBottomBar()
        let stack = NSStackView(views: [rowsStack, bottomBar])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in [rowsStack, bottomBar] {
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12).isActive = true
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12).isActive = true
        }

        let content = MeetingDropView()
        content.onDrop = { [weak self] entry in self?.model.add(entry) ?? false }
        content.onDropTargetChanged = { [weak self] targeted in self?.isDropTarget = targeted }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        return content
    }

    private func makeBottomBar() -> NSStackView {
        startButton.target = self
        startButton.action = #selector(submit)
        startButton.bezelStyle = .rounded

        field.placeholderString = "5m Tea, 1h30m, 90s, 9:30am Call…"
        field.delegate = self
        field.target = self
        field.action = #selector(submit)

        let bar = NSStackView(views: [field, startButton])
        bar.orientation = .horizontal
        bar.distribution = .fill
        bar.spacing = 8
        bar.setHuggingPriority(.defaultHigh, for: .vertical)
        return bar
    }

    // MARK: Showing

    func show() {
        // The window's spot may have gone away since it was last shown (e.g. a display was unplugged).
        if !panel.isVisible, !isOnScreen(panel.frame) { placeAtDefault() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func toggle() {
        if panel.isVisible { panel.close() } else { show() }
    }

    /// Updates every row; called on each tick and whenever the timers change.
    func refresh() {
        let ids = model.timers.map(\.id)
        if ids != rowIDs || rowsStack.arrangedSubviews.isEmpty { rebuildRows(for: ids) }

        let flashOn = Int(Date().timeIntervalSinceReferenceDate * 2) % 2 == 0
        for item in model.timers {
            guard let row = rows[item.id] else { continue }
            row.caption.stringValue = caption(for: item)
            row.labelText = item.entry.label
            row.countdown.text = formatCountdown(item.remaining)
            row.countdown.color = item.isRinging && flashOn ? .systemRed : .labelColor
        }
    }

    private func caption(for item: TimerModel.Item) -> String {
        let formatter = Calendar.current.isDateInToday(item.entry.end) ? timeFormatter : dayTimeFormatter
        let end = formatter.string(from: item.entry.end)
        switch item.entry.kind {
        case .alarm: return "Alarm · \(end)"
        case .timer: return item.isRinging ? "Time's up!" : "Timer · ends \(end)"
        }
    }

    // MARK: Rows

    /// Swaps in one row per timer, then fits the window to them.
    private func rebuildRows(for ids: [UUID]) {
        for view in rowsStack.arrangedSubviews {
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        rows = rows.filter { ids.contains($0.key) }
        for id in ids {
            let row = rows[id] ?? makeRow(for: id)
            rows[id] = row
            addRow(row)
        }
        if ids.isEmpty { addRow(idleRow) }
        rowIDs = ids
        fitHeight()
    }

    private func makeRow(for id: UUID) -> TimerRowView {
        let row = TimerRowView(showsStop: true)
        row.isDropTarget = isDropTarget
        row.tileHeight = tileSize.height
        row.onStop = { [weak self] in self?.model.remove(id: id) }
        return row
    }

    private func addRow(_ row: TimerRowView) {
        rowsStack.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor).isActive = true
    }

    // MARK: Window placement

    /// Sizes the window to its tiles, keeping the top edge where it is. The user can resize only the width.
    private func fitHeight() {
        guard let content = panel.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let contentHeight = content.fittingSize.height
        panel.contentMinSize = NSSize(width: 220, height: contentHeight)
        panel.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: contentHeight)

        var frame = panel.frame
        let top = frame.maxY
        frame.size.height = panel.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: frame.width, height: contentHeight))).height
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.size.height = min(frame.size.height, visible.height)
            frame.origin.y = max(top - frame.size.height, visible.minY)
        } else {
            frame.origin.y = top - frame.size.height
        }
        place(frame)
    }

    private func place(_ frame: NSRect) {
        isPlacing = true
        panel.setFrame(frame, display: true)
        isPlacing = false
    }

    /// Puts the window back where the user left it. Only the top-left corner and width are used; the height comes from the tiles.
    private func restoreFrame() {
        if let saved = UserDefaults.standard.string(forKey: frameDefaultsKey) {
            let savedFrame = NSRectFromString(saved)
            var frame = panel.frame
            frame.size.width = savedFrame.width
            frame.origin = NSPoint(x: savedFrame.minX, y: savedFrame.maxY - frame.height)
            if isOnScreen(frame) {
                place(frame)
                return
            }
        }
        placeAtDefault()
    }

    /// Upper right of the screen that has focus, keeping the current size.
    private func placeAtDefault() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let margin: CGFloat = 16
        let visible = screen.visibleFrame
        let size = panel.frame.size
        place(NSRect(x: visible.maxX - size.width - margin,
                     y: visible.maxY - size.height - margin,
                     width: size.width, height: size.height))
    }

    /// On screen means enough of the window shows on some display to grab and use it.
    private func isOnScreen(_ frame: NSRect) -> Bool {
        guard frame.width > 0, frame.height > 0 else { return false }
        return NSScreen.screens.contains { screen in
            let shown = screen.visibleFrame.intersection(frame)
            return shown.width >= min(frame.width, 100) && shown.height >= min(frame.height, 60)
        }
    }

    private func saveFrame() {
        guard !isPlacing else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameDefaultsKey)
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    // MARK: Entry

    @objc private func submit() {
        guard !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let entry = EntryParser.parse(field.stringValue) else {
            field.textColor = .systemRed
            NSSound.beep()
            return
        }
        field.stringValue = ""
        updateStartButton()
        if !model.add(entry) { NSSound.beep() }  // already running
    }

    func controlTextDidChange(_ obj: Notification) {
        field.textColor = .labelColor
        updateStartButton()
    }

    private func updateStartButton() {
        startButton.isEnabled = EntryParser.parse(field.stringValue) != nil
    }
}
