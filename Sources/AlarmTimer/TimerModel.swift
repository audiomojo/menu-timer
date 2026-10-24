import AppKit

/// The running and ringing timers, the clock that advances them, and the ring while any are done.
/// Timers are saved on every change and restored at launch, so they survive quitting and restarts.
@MainActor
final class TimerModel: NSObject {
    struct Item {
        let id = UUID()
        let entry: Entry
        var isRinging = false

        var remaining: TimeInterval {
            isRinging ? 0 : max(0, entry.end.timeIntervalSinceNow)
        }

        var isDue: Bool { !isRinging && entry.end.timeIntervalSinceNow <= 0 }

        /// Within a second counts as the same time, since that's all the countdown shows.
        func firesWithEntry(_ other: Entry) -> Bool {
            !isRinging && abs(entry.end.timeIntervalSince(other.end)) < 1
        }
    }

    /// Running and ringing timers, soonest-ending first (next to go off at the top).
    private(set) var timers: [Item] = []
    /// Called on every tick and on every change to `timers`.
    var onUpdate: (() -> Void)?
    /// Called when one or more timers reach zero.
    var onFire: (() -> Void)?

    private let defaults: UserDefaults
    static let defaultsKey = "timers"

    private var ticker: Timer?
    private let tickInterval: TimeInterval = 0.2
    private var lastRing = Date.distantPast
    private let ringInterval: TimeInterval = 1.5

    /// Restores saved timers. Any that ran out while the app wasn't running ring on the first tick.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        let saved = defaults.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        timers = saved.sorted { $0.end < $1.end }.map { Item(entry: $0) }
        changed()
    }

    var isRinging: Bool { timers.contains { $0.isRinging } }
    /// Time left on whichever timer finishes first; nil when nothing is running.
    var soonestRemaining: TimeInterval? { timers.map(\.remaining).min() }

    /// Adds the entry unless something still counting down would go off at the same time.
    /// Returns false when it was a duplicate and nothing was added.
    @discardableResult
    func add(_ entry: Entry) -> Bool {
        guard !timers.contains(where: { $0.firesWithEntry(entry) }) else { return false }
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

    /// Saves the timers and runs the clock only while there's something to count down.
    private func changed() {
        save()
        if timers.isEmpty {
            ticker?.invalidate()
            ticker = nil
        } else if ticker == nil {
            let timer = Timer(timeInterval: tickInterval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        }
        onUpdate?()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(timers.map(\.entry)) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    @objc private func tick() {
        startRingingDueTimers()
        ringIfNeeded()
        onUpdate?()
    }

    private func startRingingDueTimers() {
        let due = timers.indices.filter { timers[$0].isDue }
        guard !due.isEmpty else { return }
        for index in due { timers[index].isRinging = true }
        lastRing = .distantPast  // ring right away
        onFire?()
    }

    private func ringIfNeeded() {
        guard isRinging, Date().timeIntervalSince(lastRing) >= ringInterval else { return }
        lastRing = Date()
        AlarmSound.current().play()
    }
}
