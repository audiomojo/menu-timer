import AppKit

/// The window's content view: accepts meetings dragged from Outlook and hands them on as alarms.
final class MeetingDropView: NSView {
    /// Called with the dropped meeting; returns false if it wasn't added (e.g. already running).
    var onDrop: ((Entry) -> Bool)?
    /// Called with true while a meeting that can be dropped is over the window, and false once it leaves or drops.
    var onDropTargetChanged: ((Bool) -> Void)?

    private var isTargeted = false {
        didSet { if isTargeted != oldValue { onDropTargetChanged?(isTargeted) } }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.string])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func meeting(in sender: NSDraggingInfo) -> Entry? {
        sender.draggingPasteboard.string(forType: .string).flatMap { OutlookMeeting.entry(fromText: $0) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { operation(for: sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { operation(for: sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { isTargeted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { isTargeted = false }

    private func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        isTargeted = meeting(in: sender) != nil
        return isTargeted ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        guard let entry = meeting(in: sender) else { return false }
        if onDrop?(entry) != true { NSSound.beep() }
        return true
    }
}
