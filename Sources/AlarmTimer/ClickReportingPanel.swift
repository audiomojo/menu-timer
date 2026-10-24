import AppKit

/// Panel that reports every mouse-down inside it (title bar included) and shows a context menu on right-click.
final class ClickReportingPanel: NSPanel {
    var onMouseDown: (() -> Void)?
    /// Shown on right-click anywhere except the text field, which keeps its own edit menu.
    var contextMenu: NSMenu?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .rightMouseDown, let menu = contextMenu, let content = contentView, !isOverTextField(event) {
            onMouseDown?()
            NSMenu.popUpContextMenu(menu, with: event, for: content)
            return
        }
        super.sendEvent(event)
        // Reported after normal handling, so rows can't shift under the cursor mid-click.
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            onMouseDown?()
        }
    }

    private func isOverTextField(_ event: NSEvent) -> Bool {
        guard let content = contentView else { return false }
        let hit = content.hitTest(content.convert(event.locationInWindow, from: nil))
        return hit is NSText || (hit as? NSTextField)?.isEditable == true
    }
}
