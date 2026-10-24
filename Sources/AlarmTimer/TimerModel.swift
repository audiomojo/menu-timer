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

    /// Running and ringing timers, soonest-ending first (next to go off at the top).
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

    /// Adds the entry unless something still counting down would go off at the same time.
    /// Returns false when it was a duplicate and nothing was added.
    @discardableResult
    func add(_ entry: Entry) -> Bool {
        // Within a second counts as the same time, since that's all the countdown shows.
        let duplicate = timers.contains { !$0.isRinging && abs($0.entry.end.timeIntervalSince(entry.end)) < 1 }
        guard !duplicate else { return false }
        let index = timers.firstIndex { $0.entry.end > entry.end } ?? timers.endIndex
        timers.insert(Item(entry: entry), at: index)
        changed()
        return true
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
            AlarmSound.current().play()
        }
        onUpdate?()
    }
}
