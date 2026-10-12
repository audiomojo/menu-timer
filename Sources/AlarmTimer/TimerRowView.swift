import AppKit

/// One stacked sub-panel: a caption, an optional stop (circled x) button, and a countdown.
final class TimerRowView: NSView {
    let caption = NSTextField(labelWithString: "")
    let countdown = CountdownView()
    var onStop: (() -> Void)?

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

        for view in [background, countdown, caption] {
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

            countdown.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 2),
            countdown.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            countdown.leadingAnchor.constraint(equalTo: leadingAnchor),
            countdown.trailingAnchor.constraint(equalTo: trailingAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
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
