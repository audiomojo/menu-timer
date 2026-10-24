import AppKit

/// Parser and model checks, run with `AlarmTimer --self-test` (XCTest isn't available without Xcode).
@MainActor
func runSelfTest() -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    // Wednesday 2026-01-14 10:00:00 local
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 10))!
    var failures = 0

    func check(_ input: String, _ kind: Entry.Kind?, secondsFromNow: TimeInterval = 0) {
        let entry = EntryParser.parse(input, now: now, calendar: calendar)
        let ok = entry?.kind == kind && (kind == nil || entry?.end.timeIntervalSince(now) == secondsFromNow)
        if !ok {
            failures += 1
            let got = entry.map { "\($0.kind) +\($0.end.timeIntervalSince(now))s" } ?? "nil"
            print("FAIL \"\(input)\": expected \(kind.map { "\($0) +\(secondsFromNow)s" } ?? "nil"), got \(got)")
        }
    }

    check("5m", .timer, secondsFromNow: 300)
    check("20m", .timer, secondsFromNow: 1200)
    check("20", .timer, secondsFromNow: 1200)
    check("1.5", .timer, secondsFromNow: 90)
    check("90s", .timer, secondsFromNow: 90)
    check("1h30m", .timer, secondsFromNow: 5400)
    check("1h 30m 10s", .timer, secondsFromNow: 5410)
    check("2 hours", .timer, secondsFromNow: 7200)
    check("10 min", .timer, secondsFromNow: 600)
    check(" 5M ", .timer, secondsFromNow: 300)

    check("11:45am", .alarm, secondsFromNow: 105 * 60)
    check("11:45 AM", .alarm, secondsFromNow: 105 * 60)
    check("2:30pm", .alarm, secondsFromNow: 270 * 60)
    check("2:30p", .alarm, secondsFromNow: 270 * 60)
    check("2pm", .alarm, secondsFromNow: 240 * 60)
    check("12pm", .alarm, secondsFromNow: 120 * 60)
    check("12am", .alarm, secondsFromNow: 14 * 3600)
    check("9:30am", .alarm, secondsFromNow: 23.5 * 3600)   // already passed: tomorrow
    check("10:00am", .alarm, secondsFromNow: 24 * 3600)    // exactly now: tomorrow
    check("14:30", .alarm, secondsFromNow: 270 * 60)
    check("9:30", .alarm, secondsFromNow: 11.5 * 3600)     // no am/pm: next occurrence (9:30pm)
    check("10:15", .alarm, secondsFromNow: 15 * 60)
    check("12:15", .alarm, secondsFromNow: 135 * 60)

    for bad in ["", "abc", "0m", "0", "13pm", "25:00", "9:75am", "m", "5x", "-5", "5m9:30am"] {
        check(bad, nil)
    }

    // Text after the time becomes the label.
    func checkLabel(_ input: String, _ label: String, secondsFromNow: TimeInterval) {
        let entry = EntryParser.parse(input, now: now, calendar: calendar)
        if entry?.label != label || entry?.end.timeIntervalSince(now) != secondsFromNow {
            failures += 1
            print("FAIL label \"\(input)\": expected \"\(label)\" +\(secondsFromNow)s, got \(entry.map { "\"\($0.label)\" +\($0.end.timeIntervalSince(now))s" } ?? "nil")")
        }
    }
    checkLabel("5m Flip Pancakes", "Flip Pancakes", secondsFromNow: 300)
    checkLabel("5m", "", secondsFromNow: 300)
    checkLabel("  5m   Flip   Pancakes  ", "Flip Pancakes", secondsFromNow: 300)
    checkLabel("1h 30m Tea", "Tea", secondsFromNow: 5400)
    checkLabel("10 min Eggs", "Eggs", secondsFromNow: 600)
    checkLabel("20 Laundry", "Laundry", secondsFromNow: 1200)
    checkLabel("11:45 AM Call Mom", "Call Mom", secondsFromNow: 105 * 60)
    checkLabel("2pm Meeting at 3", "Meeting at 3", secondsFromNow: 240 * 60)
    for bad in ["Flip Pancakes", "Tea 5m", "5x Tea"] { check(bad, nil) }

    let formats: [(TimeInterval, String)] = [(0, "0:00"), (0.2, "0:01"), (59, "0:59"), (300, "5:00"), (3599.5, "1:00:00"), (5410, "1:30:10")]
    for (interval, expected) in formats where formatCountdown(interval) != expected {
        failures += 1
        print("FAIL format \(interval): expected \(expected), got \(formatCountdown(interval))")
    }

    // Adding a timer or alarm that's already counting down is ignored.
    func expect(_ condition: Bool, _ message: String) {
        if !condition {
            failures += 1
            print("FAIL \(message)")
        }
    }
    // Adding something that would go off at the same time as a running entry is ignored.
    let model = TimerModel()
    let start = Date()
    func add(_ text: String, after seconds: TimeInterval = 0) -> Bool {
        model.add(EntryParser.parse(text, now: start.addingTimeInterval(seconds))!)
    }
    expect(add("5m"), "first 5m timer should be added")
    expect(!add("5m"), "5m entered at the same moment should be ignored")
    expect(!add("300s", after: 0.3), "300s entered a moment later ends at the same time and should be ignored")
    expect(add("5m", after: 30), "5m entered 30s later ends later and should be added")
    expect(add("20m"), "first 20m timer should be added")
    expect(add("20m", after: 5), "20m entered 5s later should be added")
    expect(add("9pm"), "first 9pm alarm should be added")
    expect(!add("9:00 PM", after: 10), "second 9pm alarm should be ignored")
    expect(add("9:01pm"), "9:01pm alarm should be added")
    expect(model.timers.count == 6, "expected 6 entries, got \(model.timers.count)")
    model.removeAll()
    expect(add("5m"), "5m should be added again after stopping")
    model.removeAll()

    // Entries are listed with the soonest to go off first.
    for text in ["5m", "1h", "30s", "20m", "10m"] { _ = add(text) }
    let order = model.timers.map { $0.entry.end.timeIntervalSince(start) }
    expect(order == [30, 300, 600, 1200, 3600], "expected soonest-first order, got \(order)")
    model.removeAll()

    // Ten named sounds that all exist, defaulting to Chime and remembering the choice.
    expect(AlarmSound.allCases.count == 10, "expected 10 sounds, got \(AlarmSound.allCases.count)")
    expect(Set(AlarmSound.allCases.map(\.title)).count == 10, "sound names should be unique")
    for sound in AlarmSound.allCases where NSSound(named: sound.rawValue) == nil {
        expect(false, "system sound \(sound.rawValue) for \(sound.title) is missing")
    }
    let suite = "AlarmTimer.selftest"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    expect(AlarmSound.current(in: defaults) == .chime, "default sound should be Chime")
    AlarmSound.sonar.save(in: defaults)
    expect(AlarmSound.current(in: defaults) == .sonar, "saved sound should be Sonar")
    defaults.set("NoSuchSound", forKey: AlarmSound.defaultsKey)
    expect(AlarmSound.current(in: defaults) == .chime, "unknown saved sound should fall back to Chime")
    defaults.removePersistentDomain(forName: suite)

    // The countdown is centered on the row and stays clear of the caption and label.
    for height: CGFloat in [120, 160, 200] {
        let row = TimerRowView(showsStop: true)
        row.caption.stringValue = "Timer · ends 9:00 PM"
        row.label.stringValue = "Flip Pancakes"
        row.countdown.text = "12:34"
        row.frame = NSRect(x: 0, y: 0, width: 300, height: height)
        row.layoutSubtreeIfNeeded()
        let box = row.countdown.frame
        expect(abs(box.midY - height / 2) < 0.5 && abs(box.midX - 150) < 0.5,
               "countdown area off center in \(height)pt row: \(box)")
        expect(box.maxY <= row.label.frame.minY, "countdown overlaps label in \(height)pt row")
        expect(box.height >= 30, "countdown area too small in \(height)pt row: \(box.height)")
        if let digits = row.countdown.textRect() {
            expect(abs(digits.digitsMidY - box.height / 2) < 0.5, "digits not vertically centered: \(digits.digitsMidY) vs \(box.height / 2)")
        } else {
            expect(false, "countdown has nothing to draw")
        }
    }

    print(failures == 0 ? "All self-tests passed" : "\(failures) self-test failure(s)")
    return failures == 0
}
