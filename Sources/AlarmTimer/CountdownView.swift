import AppKit

/// Draws the countdown centered, scaled to fill the available space.
final class CountdownView: NSView {
    var text = "" { didSet { if text != oldValue { needsDisplay = true } } }
    var color = NSColor.labelColor { didSet { if color != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        let reference: CGFloat = 100
        let font = NSFont.monospacedDigitSystemFont(ofSize: reference, weight: .medium)
        let measured = (text as NSString).size(withAttributes: [.font: font])
        guard measured.width > 0, measured.height > 0 else { return }

        let scale = min(bounds.width * 0.92 / measured.width, bounds.height * 0.9 / measured.height)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: reference * scale, weight: .medium),
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }
}
