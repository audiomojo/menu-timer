import AppKit

/// The window's content view: accepts meetings dragged from Outlook and hands them on as alarms.
final class MeetingDropView: NSView {
    /// Called with the dropped meeting; returns false if it wasn't added (e.g. already running).
    var onDrop: ((Entry) -> Bool)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.string])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func meeting(in sender: NSDraggingInfo) -> Entry? {
        sender.draggingPasteboard.string(forType: .string).flatMap { OutlookMeeting.entry(fromText: $0) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        meeting(in: sender) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        meeting(in: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let entry = meeting(in: sender) else { return false }
        if onDrop?(entry) != true { NSSound.beep() }
        return true
    }
}
