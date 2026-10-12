import AppKit

/// Panel that reports every mouse-down inside it (title bar included).
final class ClickReportingPanel: NSPanel {
    var onMouseDown: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        // Reported after normal handling, so rows can't shift under the cursor mid-click.
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            onMouseDown?()
        }
    }
}

@MainActor
final class TimerWindowController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let panel: ClickReportingPanel
    private let model: TimerModel
    private let rowsStack = NSStackView()
    /// Placeholder shown when no timers are running.
    private let idleRow = TimerRowView(showsStop: false)
    private var rows: [UUID: TimerRowView] = [:]
    private var rowIDs: [UUID] = []
    private let field = NSTextField()
    private let startButton = NSButton(title: "Start", target: nil, action: nil)

    private let rowSpacing: CGFloat = 6
    private let frameDefaultsKey = "panelFrame"
    /// True while we position the panel ourselves, so only user moves/resizes get saved.
    private var isPlacing = false

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    init(model: TimerModel) {
        self.model = model
        panel = ClickReportingPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
                                    styleMask: [.titled, .closable, .resizable],
                                    backing: .buffered, defer: false)
        super.init()

        panel.title = "Alarm Timer"
        // Any click in the window silences (and clears) the timers that are ringing.
        panel.onMouseDown = { [weak self] in
            guard let self, self.model.isRinging else { return }
            self.model.removeRinging()
        }
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentMinSize = NSSize(width: 220, height: 120)

        idleRow.caption.stringValue = "Enter a Duration or Time"
        idleRow.countdown.text = formatCountdown(0)
        idleRow.countdown.color = .tertiaryLabelColor

        rowsStack.orientation = .vertical
        rowsStack.alignment = .centerX
        rowsStack.distribution = .fillEqually
        rowsStack.spacing = rowSpacing
        rowsStack.setHuggingPriority(NSLayoutConstraint.Priority(1), for: .vertical)

        startButton.target = self
        startButton.action = #selector(submit)
        startButton.bezelStyle = .rounded

        field.placeholderString = "5m, 1h30m, 90s, 9:30am, 2:30pm…"
        field.delegate = self
        field.target = self
        field.action = #selector(submit)

        let bottomBar = NSStackView(views: [field, startButton])
        bottomBar.orientation = .horizontal
        bottomBar.distribution = .fill
        bottomBar.spacing = 8
        bottomBar.setHuggingPriority(.defaultHigh, for: .vertical)

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

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        panel.contentView = content
        refresh()
        restoreFrame()
        panel.delegate = self
    }

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

    func refresh() {
        let ids = model.timers.map(\.id)
        if ids != rowIDs || rowsStack.arrangedSubviews.isEmpty { rebuildRows(for: ids) }

        let flashOn = Int(Date().timeIntervalSinceReferenceDate * 2) % 2 == 0
        for item in model.timers {
            guard let row = rows[item.id] else { continue }
            let end = timeFormatter.string(from: item.entry.end)
            row.countdown.text = formatCountdown(item.remaining)
            if item.isRinging {
                row.countdown.color = flashOn ? .systemRed : .labelColor
                row.caption.stringValue = item.entry.kind == .timer ? "Time's up!" : "Alarm · \(end)"
            } else {
                row.countdown.color = .labelColor
                row.caption.stringValue = item.entry.kind == .timer ? "Timer · ends \(end)" : "Alarm · \(end)"
            }
        }
        startButton.isEnabled = EntryParser.parse(field.stringValue) != nil
    }

    // MARK: Rows

    /// Swaps in one row per timer and grows or shrinks the window downward so each row keeps its height.
    private func rebuildRows(for ids: [UUID]) {
        let shown = rowsStack.arrangedSubviews
        panel.contentView?.layoutSubtreeIfNeeded()
        let rowHeight = shown.first?.frame.height ?? 0
        let newCount = max(1, ids.count)
        let oldCount = shown.isEmpty ? newCount : shown.count

        for view in shown {
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

        guard newCount != oldCount else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size.height += CGFloat(newCount - oldCount) * (rowHeight + rowSpacing)
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.size.height = min(frame.size.height, visible.height)
            frame.origin.y = max(top - frame.size.height, visible.minY)
        } else {
            frame.origin.y = top - frame.size.height
        }
        place(frame)
    }

    private func makeRow(for id: UUID) -> TimerRowView {
        let row = TimerRowView(showsStop: true)
        row.onStop = { [weak self] in self?.model.remove(id: id) }
        return row
    }

    private func addRow(_ row: TimerRowView) {
        rowsStack.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor).isActive = true
    }

    // MARK: Window placement

    private func place(_ frame: NSRect) {
        isPlacing = true
        panel.setFrame(frame, display: true)
        isPlacing = false
    }

    /// Called at launch, while the window still shows a single row.
    private func restoreFrame() {
        if let saved = UserDefaults.standard.string(forKey: frameDefaultsKey) {
            let frame = NSRectFromString(saved)
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

    /// Saves the frame as it would be with a single row, since that's what the window launches with.
    private func saveFrame() {
        guard !isPlacing else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        var frame = panel.frame
        let rowHeight = rowsStack.arrangedSubviews.first?.frame.height ?? 0
        let extra = CGFloat(rowsStack.arrangedSubviews.count - 1) * (rowHeight + rowSpacing)
        if extra > 0 {
            frame.origin.y += extra
            frame.size.height -= extra
        }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: frameDefaultsKey)
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    // MARK: Entry

    @objc private func submit() {
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        guard let entry = EntryParser.parse(text) else {
            field.textColor = .systemRed
            NSSound.beep()
            return
        }
        field.stringValue = ""
        model.add(entry)
    }

    func controlTextDidChange(_ obj: Notification) {
        field.textColor = .labelColor
        refresh()
    }
}
