import AppKit

/// Draws the countdown centered, scaled to fill the available space.
final class CountdownView: NSView {
    var text = "" { didSet { if text != oldValue { needsDisplay = true } } }
    var color = NSColor.labelColor { didSet { if color != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        guard let rect = textRect() else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: font(ofSize: rect.fontSize), .foregroundColor: color]
        (text as NSString).draw(at: rect.origin, withAttributes: attributes)
    }

    /// Where `draw(at:)` should put the text, and how big, so the digits fill the view and sit on its center.
    /// Centers on the digits' height (cap height) rather than the line box, which has room for descenders.
    func textRect() -> (origin: NSPoint, fontSize: CGFloat, digitsMidY: CGFloat)? {
        let reference: CGFloat = 100
        let measured = (text as NSString).size(withAttributes: [.font: font(ofSize: reference)])
        let referenceCap = font(ofSize: reference).capHeight
        guard measured.width > 0, referenceCap > 0, bounds.height > 0 else { return nil }

        let scale = min(bounds.width * 0.92 / measured.width, bounds.height * 0.9 / referenceCap)
        let font = font(ofSize: reference * scale)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        let baseline = bounds.midY - font.capHeight / 2
        // draw(at:) places the bottom of the line box, which sits one descender below the baseline.
        let origin = NSPoint(x: bounds.midX - width / 2, y: baseline + font.descender)
        return (origin, font.pointSize, baseline + font.capHeight / 2)
    }

    private func font(ofSize size: CGFloat) -> NSFont {
        .monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }
}
