import AppKit

/// Checks run with `AlarmTimer --self-test` (XCTest isn't available without Xcode).
@MainActor
func runSelfTest() -> Bool {
    let run = SelfTestRun()
    testParser(run)
    testCountdownFormat(run)
    testModel(run)
    testPersistence(run)
    testSounds(run)
    testRowLayout(run)
    print(run.failures == 0 ? "All self-tests passed" : "\(run.failures) self-test failure(s)")
    return run.failures == 0
}

/// Counts and prints failed checks.
private final class SelfTestRun {
    private(set) var failures = 0

    func expect(_ condition: Bool, _ message: @autoclosure () -> String) {
        guard !condition else { return }
        failures += 1
        print("FAIL \(message())")
    }
}

private func testParser(_ run: SelfTestRun) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    // Wednesday 2026-01-14 10:00:00 local
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 10))!

    func describe(_ entry: Entry?) -> String {
        entry.map { "\($0.kind) +\($0.end.timeIntervalSince(now))s \"\($0.label)\"" } ?? "nil"
    }
    func check(_ input: String, _ kind: Entry.Kind, in seconds: TimeInterval, label: String = "") {
        let entry = EntryParser.parse(input, now: now, calendar: calendar)
        let ok = entry?.kind == kind && entry?.end.timeIntervalSince(now) == seconds && entry?.label == label
        run.expect(ok, "parse \"\(input)\": expected \(kind) +\(seconds)s \"\(label)\", got \(describe(entry))")
    }
    func checkInvalid(_ input: String) {
        let entry = EntryParser.parse(input, now: now, calendar: calendar)
        run.expect(entry == nil, "parse \"\(input)\": expected nil, got \(describe(entry))")
    }

    check("5m", .timer, in: 300)
    check("20m", .timer, in: 1200)
    check("20", .timer, in: 1200)
    check("1.5", .timer, in: 90)
    check("90s", .timer, in: 90)
    check("1h30m", .timer, in: 5400)
    check("1h 30m 10s", .timer, in: 5410)
    check("2 hours", .timer, in: 7200)
    check("10 min", .timer, in: 600)
    check(" 5M ", .timer, in: 300)

    check("11:45am", .alarm, in: 105 * 60)
    check("11:45 AM", .alarm, in: 105 * 60)
    check("2:30pm", .alarm, in: 270 * 60)
    check("2:30p", .alarm, in: 270 * 60)
    check("2pm", .alarm, in: 240 * 60)
    check("12pm", .alarm, in: 120 * 60)
    check("12am", .alarm, in: 14 * 3600)
    check("9:30am", .alarm, in: 23.5 * 3600)   // already passed: tomorrow
    check("10:00am", .alarm, in: 24 * 3600)    // exactly now: tomorrow
    check("14:30", .alarm, in: 270 * 60)
    check("9:30", .alarm, in: 11.5 * 3600)     // no am/pm: next occurrence (9:30pm)
    check("10:15", .alarm, in: 15 * 60)
    check("12:15", .alarm, in: 135 * 60)

    // Text after the time becomes the label.
    check("5m Flip Pancakes", .timer, in: 300, label: "Flip Pancakes")
    check("  5m   Flip   Pancakes  ", .timer, in: 300, label: "Flip Pancakes")
    check("1h 30m Tea", .timer, in: 5400, label: "Tea")
    check("10 min Eggs", .timer, in: 600, label: "Eggs")
    check("20 Laundry", .timer, in: 1200, label: "Laundry")
    check("11:45 AM Call Mom", .alarm, in: 105 * 60, label: "Call Mom")
    check("2pm Meeting at 3", .alarm, in: 240 * 60, label: "Meeting at 3")

    for bad in ["", "abc", "0m", "0", "13pm", "25:00", "9:75am", "m", "5x", "-5", "5m9:30am",
                "Flip Pancakes", "Tea 5m", "5x Tea"] {
        checkInvalid(bad)
    }
}

private func testCountdownFormat(_ run: SelfTestRun) {
    let formats: [(TimeInterval, String)] = [(0, "0:00"), (0.2, "0:01"), (59, "0:59"), (300, "5:00"), (3599.5, "1:00:00"), (5410, "1:30:10")]
    for (interval, expected) in formats {
        run.expect(formatCountdown(interval) == expected, "format \(interval): expected \(expected), got \(formatCountdown(interval))")
    }
}

/// Scratch settings for tests, so they never touch the app's saved timers or sound.
private func withTestDefaults(_ body: (UserDefaults) -> Void) {
    let suite = "AlarmTimer.selftest"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    body(defaults)
}

@MainActor
private func testModel(_ run: SelfTestRun) {
    withTestDefaults { defaults in
        let model = TimerModel(defaults: defaults)
        let start = Date()
        @MainActor func add(_ text: String, after seconds: TimeInterval = 0) -> Bool {
            model.add(EntryParser.parse(text, now: start.addingTimeInterval(seconds))!)
        }

        // Adding something that would go off at the same time as a running entry is ignored.
        run.expect(add("5m"), "first 5m timer should be added")
        run.expect(!add("5m"), "5m entered at the same moment should be ignored")
        run.expect(!add("300s", after: 0.3), "300s entered a moment later ends at the same time and should be ignored")
        run.expect(add("5m", after: 30), "5m entered 30s later ends later and should be added")
        run.expect(add("20m"), "first 20m timer should be added")
        run.expect(add("20m", after: 5), "20m entered 5s later should be added")
        run.expect(add("9pm"), "first 9pm alarm should be added")
        run.expect(!add("9:00 PM", after: 10), "second 9pm alarm should be ignored")
        run.expect(add("9:01pm"), "9:01pm alarm should be added")
        run.expect(model.timers.count == 6, "expected 6 entries, got \(model.timers.count)")
        model.removeAll()
        run.expect(add("5m"), "5m should be added again after stopping")
        model.removeAll()

        // Entries are listed with the soonest to go off first.
        for text in ["5m", "1h", "30s", "20m", "10m"] { _ = add(text) }
        let order = model.timers.map { $0.entry.end.timeIntervalSince(start) }
        run.expect(order == [30, 300, 600, 1200, 3600], "expected soonest-first order, got \(order)")
        model.removeAll()
    }
}

@MainActor
private func testPersistence(_ run: SelfTestRun) {
    withTestDefaults { defaults in
        // Timers come back after a relaunch with the same end time, kind, label and order.
        let first = TimerModel(defaults: defaults)
        run.expect(first.timers.isEmpty, "nothing saved should restore no timers")
        first.add(EntryParser.parse("20m Laundry")!)
        first.add(EntryParser.parse("5m")!)
        first.add(EntryParser.parse("9pm Call Mom")!)
        let saved = first.timers.map(\.entry)

        let relaunched = TimerModel(defaults: defaults)
        let restored = relaunched.timers.map(\.entry)
        run.expect(restored.map(\.end) == saved.map(\.end), "restored end times differ: \(restored.map(\.end)) vs \(saved.map(\.end))")
        run.expect(restored.map(\.kind) == saved.map(\.kind), "restored kinds differ")
        run.expect(restored.map(\.label) == saved.map(\.label), "restored labels differ: \(restored.map(\.label))")
        run.expect(relaunched.soonestRemaining.map { $0 > 290 && $0 <= 300 } == true,
                   "restored 5m timer should still be counting down, got \(String(describing: relaunched.soonestRemaining))")

        // Stopping a timer is saved too.
        relaunched.timers.first.map { relaunched.remove(id: $0.id) }
        run.expect(TimerModel(defaults: defaults).timers.count == 2, "removed timer should stay removed after relaunch")
        relaunched.removeAll()
        run.expect(TimerModel(defaults: defaults).timers.isEmpty, "Stop All should leave nothing to restore")

        // A timer that ran out while the app was closed is due right away, so it rings on launch.
        let past = EntryParser.parse("1m Tea", now: Date().addingTimeInterval(-3600))!
        defaults.set(try! JSONEncoder().encode([past]), forKey: TimerModel.defaultsKey)
        let afterRestart = TimerModel(defaults: defaults)
        run.expect(afterRestart.timers.first?.isDue == true, "timer that ended while closed should be due on launch")
        afterRestart.removeAll()

        // Unreadable saved data is ignored rather than crashing.
        defaults.set(Data("not json".utf8), forKey: TimerModel.defaultsKey)
        run.expect(TimerModel(defaults: defaults).timers.isEmpty, "corrupt saved timers should restore nothing")
    }
}

private func testSounds(_ run: SelfTestRun) {
    // Ten named sounds that all exist, defaulting to Chime and remembering the choice.
    run.expect(AlarmSound.allCases.count == 10, "expected 10 sounds, got \(AlarmSound.allCases.count)")
    run.expect(Set(AlarmSound.allCases.map(\.title)).count == 10, "sound names should be unique")
    for sound in AlarmSound.allCases {
        run.expect(NSSound(named: sound.rawValue) != nil, "system sound \(sound.rawValue) for \(sound.title) is missing")
    }

    withTestDefaults { defaults in
        run.expect(AlarmSound.current(in: defaults) == .chime, "default sound should be Chime")
        AlarmSound.sonar.save(in: defaults)
        run.expect(AlarmSound.current(in: defaults) == .sonar, "saved sound should be Sonar")
        defaults.set("NoSuchSound", forKey: AlarmSound.defaultsKey)
        run.expect(AlarmSound.current(in: defaults) == .chime, "unknown saved sound should fall back to Chime")
    }
}

@MainActor
private func testRowLayout(_ run: SelfTestRun) {
    // The countdown sits below the caption (and label, when there is one) with a gap, filling the rest of the row.
    for labelText in ["Flip Pancakes", ""] {
        for height: CGFloat in [100, 200] {
            let name = "\(labelText.isEmpty ? "unlabeled" : "labeled") \(height)pt row"
            let row = TimerRowView(showsStop: true)
            row.caption.stringValue = "Timer · ends 9:00 PM"
            row.labelText = labelText
            row.countdown.text = "12:34"
            row.frame = NSRect(x: 0, y: 0, width: 300, height: height)
            row.layoutSubtreeIfNeeded()

            let box = row.countdown.frame
            let above = labelText.isEmpty ? row.caption.frame : row.label.frame
            run.expect(row.label.isHidden == labelText.isEmpty, "label visibility wrong in \(name)")
            run.expect(abs(above.minY - box.maxY - TimerRowView.countdownGap) < 0.5,
                       "gap above countdown should be \(TimerRowView.countdownGap)pt in \(name): \(above.minY - box.maxY)")
            run.expect(abs(box.minY - TimerRowView.countdownBottomInset) < 0.5 && abs(box.midX - 150) < 0.5,
                       "countdown should fill to the bottom, centered across, in \(name): \(box)")
            testDigits(run, in: row.countdown, name: name)
        }
    }
}

/// The digits are centered on their own height and drawn at `sizeFactor` of the largest size that fits.
@MainActor
private func testDigits(_ run: SelfTestRun, in view: CountdownView, name: String) {
    guard let layout = view.layout() else {
        run.expect(false, "countdown has nothing to draw in \(name)")
        return
    }
    let font = layout.font
    let digitsMidY = layout.origin.y - font.descender + font.capHeight / 2
    run.expect(abs(digitsMidY - view.bounds.midY) < 0.5, "digits not centered in their area in \(name)")

    let width = (view.text as NSString).size(withAttributes: [.font: font]).width
    let fill = max(font.capHeight / (view.bounds.height * CountdownView.maxHeightFill),
                   width / (view.bounds.width * CountdownView.maxWidthFill))
    run.expect(abs(fill - CountdownView.sizeFactor) < 0.01,
               "digits should be drawn at \(CountdownView.sizeFactor) of the size that fits in \(name), got \(fill)")
}
