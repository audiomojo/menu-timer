import AppKit

/// One stacked sub-panel: a caption, a label line, an optional stop (circled x) button, and a countdown.
final class TimerRowView: NSView {
    let caption = TimerRowView.makeLine(font: .systemFont(ofSize: NSFont.smallSystemFontSize), color: .secondaryLabelColor)
    let label = TimerRowView.makeLine(font: .systemFont(ofSize: NSFont.systemFontSize, weight: .medium), color: .labelColor)
    let countdown = CountdownView()
    var onStop: (() -> Void)?

    /// The user's text for the timer. When blank the label line is hidden and the countdown moves up into its space.
    var labelText = "" {
        didSet {
            guard labelText != oldValue else { return }
            label.stringValue = labelText
            let hasLabel = !labelText.isEmpty
            label.isHidden = !hasLabel
            countdownBelowCaption.isActive = !hasLabel
            countdownBelowLabel.isActive = hasLabel
        }
    }

    /// Space between the text above and the countdown.
    static let countdownGap: CGFloat = 8
    static let countdownBottomInset: CGFloat = 6
    /// Equal side insets keep the text centered whether or not the stop button is shown.
    private static let sideInset: CGFloat = 28

    private lazy var countdownBelowCaption = countdown.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: Self.countdownGap)
    private lazy var countdownBelowLabel = countdown.topAnchor.constraint(equalTo: label.bottomAnchor, constant: Self.countdownGap)

    init(showsStop: Bool) {
        super.init(frame: .zero)
        label.isHidden = true

        let background = Self.makeBackground()
        for view in [background, countdown, caption, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),

            caption.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 1),

            countdownBelowCaption,
            countdown.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.countdownBottomInset),
            countdown.leadingAnchor.constraint(equalTo: leadingAnchor),
            countdown.trailingAnchor.constraint(equalTo: trailingAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
        ] + [caption, label].flatMap { line in [
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sideInset),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.sideInset),
        ] })

        if showsStop { addStopButton() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func addStopButton() {
        let symbol = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Stop")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        let button = NSButton(image: symbol ?? NSImage(), target: self, action: #selector(stopClicked))
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Stop"
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            button.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @objc private func stopClicked() {
        onStop?()
    }

    /// A centered, single-line text line that truncates instead of widening the row.
    private static func makeLine(font: NSFont, color: NSColor) -> NSTextField {
        let line = NSTextField(labelWithString: "")
        line.font = font
        line.textColor = color
        line.lineBreakMode = .byTruncatingTail
        line.alignment = .center
        line.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        line.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return line
    }

    private static func makeBackground() -> NSBox {
        let background = NSBox()
        background.boxType = .custom
        background.borderWidth = 0
        background.cornerRadius = 8
        background.fillColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.06) : NSColor(white: 0, alpha: 0.05)
        }
        return background
    }
}
