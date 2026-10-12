import AppKit

@MainActor
final class TimerModel: NSObject {
    struct Item: Equatable {
        let id = UUID()
        let entry: Entry
        var isRinging = false

        var remaining: TimeInterval {
            isRinging ? 0 : max(0, entry.end.timeIntervalSinceNow)
        }
    }

    /// Running and ringing timers, in the order they were started.
    private(set) var timers: [Item] = []
    /// Called on every tick and on every change to `timers`.
    var onUpdate: (() -> Void)?
    /// Called when one or more timers reach zero.
    var onFire: (() -> Void)?

    private var ticker: Timer?
    private var lastRing = Date.distantPast
    private let ringInterval: TimeInterval = 1.5

    var isRinging: Bool { timers.contains { $0.isRinging } }
    /// Time left on whichever timer finishes first; nil when nothing is running.
    var soonestRemaining: TimeInterval? { timers.map(\.remaining).min() }

    func add(_ entry: Entry) {
        timers.append(Item(entry: entry))
        changed()
    }

    func remove(id: UUID) {
        timers.removeAll { $0.id == id }
        changed()
    }

    func removeRinging() {
        timers.removeAll { $0.isRinging }
        changed()
    }

    func removeAll() {
        timers.removeAll()
        changed()
    }

    private func changed() {
        if timers.isEmpty {
            ticker?.invalidate()
            ticker = nil
        } else if ticker == nil {
            let timer = Timer(timeInterval: 0.2, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        }
        onUpdate?()
    }

    @objc private func tick() {
        var fired = false
        for index in timers.indices where !timers[index].isRinging && timers[index].entry.end.timeIntervalSinceNow <= 0 {
            timers[index].isRinging = true
            fired = true
        }
        if fired {
            lastRing = .distantPast
            onFire?()
        }
        if isRinging, Date().timeIntervalSince(lastRing) >= ringInterval {
            lastRing = Date()
            if let sound = NSSound(named: "Glass") { sound.play() } else { NSSound.beep() }
        }
        onUpdate?()
    }
}
