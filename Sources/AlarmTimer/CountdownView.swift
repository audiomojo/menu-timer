import AppKit

/// Draws the countdown centered, scaled to fit the available space.
final class CountdownView: NSView {
    var text = "" { didSet { if text != oldValue { needsDisplay = true } } }
    var color = NSColor.labelColor { didSet { if color != oldValue { needsDisplay = true } } }

    /// Share of the view the digits may fill at most, leaving a little breathing room at the edges.
    static let maxWidthFill: CGFloat = 0.92
    static let maxHeightFill: CGFloat = 0.9
    /// How much of that largest fitting size the digits are drawn at.
    static let sizeFactor: CGFloat = 0.8

    struct Layout {
        /// Where `draw(at:)` puts the text.
        let origin: NSPoint
        let font: NSFont
    }

    static func font(ofSize size: CGFloat) -> NSFont {
        .monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let layout = layout() else { return }
        (text as NSString).draw(at: layout.origin, withAttributes: [.font: layout.font, .foregroundColor: color])
    }

    /// Sizes the text to fit and centers it on the digits' height (cap height) rather than the
    /// font's line box, which has extra room for descenders that digits don't use.
    func layout() -> Layout? {
        let reference = Self.font(ofSize: 100)
        let referenceWidth = width(in: reference)
        guard referenceWidth > 0, reference.capHeight > 0, bounds.height > 0 else { return nil }

        let fit = min(bounds.width * Self.maxWidthFill / referenceWidth,
                      bounds.height * Self.maxHeightFill / reference.capHeight)
        let font = Self.font(ofSize: reference.pointSize * fit * Self.sizeFactor)
        let baseline = bounds.midY - font.capHeight / 2
        // draw(at:) places the bottom of the line box, which sits one descender below the baseline.
        let origin = NSPoint(x: bounds.midX - width(in: font) / 2, y: baseline + font.descender)
        return Layout(origin: origin, font: font)
    }

    private func width(in font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
