import AppKit

/// One stacked sub-panel: a caption, a label line, an optional stop (circled x) button, and a countdown.
final class TimerRowView: NSView {
    let caption = NSTextField(labelWithString: "")
    let label = NSTextField(labelWithString: "")
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
    private let countdownGap: CGFloat = 8
    private lazy var countdownBelowCaption = countdown.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: countdownGap)
    private lazy var countdownBelowLabel = countdown.topAnchor.constraint(equalTo: label.bottomAnchor, constant: countdownGap)

    init(showsStop: Bool) {
        super.init(frame: .zero)

        let background = NSBox()
        background.boxType = .custom
        background.borderWidth = 0
        background.cornerRadius = 8
        background.fillColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1, alpha: 0.06) : NSColor(white: 0, alpha: 0.05)
        }

        caption.textColor = .secondaryLabelColor
        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        caption.lineBreakMode = .byTruncatingTail
        caption.alignment = .center
        caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        caption.setContentHuggingPriority(.defaultLow, for: .horizontal)

        label.isHidden = true
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.alignment = .center
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        for view in [background, countdown, caption, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // Equal side insets keep the caption centered whether or not the stop button is shown.
        let sideInset: CGFloat = 28
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),

            caption.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideInset),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideInset),

            label.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 1),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideInset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideInset),

            countdownBelowCaption,
            countdown.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            countdown.leadingAnchor.constraint(equalTo: leadingAnchor),
            countdown.trailingAnchor.constraint(equalTo: trailingAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
        ])

        if showsStop {
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func stopClicked() {
        onStop?()
    }
}
