import Foundation

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
    let model = TimerModel()
    let later = Date().addingTimeInterval(1)
    expect(model.add(EntryParser.parse("5m")!), "first 5m timer should be added")
    expect(!model.add(EntryParser.parse("5m")!), "second 5m timer should be ignored")
    expect(!model.add(EntryParser.parse("5 min", now: later)!), "5 min entered later should match running 5m")
    expect(!model.add(EntryParser.parse("300s")!), "300s should match running 5m")
    expect(model.add(EntryParser.parse("10m")!), "10m timer should be added")
    expect(model.add(EntryParser.parse("2:30pm")!), "first 2:30pm alarm should be added")
    expect(!model.add(EntryParser.parse("2:30 PM")!), "second 2:30pm alarm should be ignored")
    expect(model.add(EntryParser.parse("2:31pm")!), "2:31pm alarm should be added")
    expect(model.timers.count == 4, "expected 4 entries, got \(model.timers.count)")
    model.removeAll()
    expect(model.add(EntryParser.parse("5m")!), "5m should be added again after stopping")
    model.removeAll()

    // Timers are listed with the soonest to go off first.
    for text in ["5m", "1h", "30s", "20m", "10m"] { model.add(EntryParser.parse(text)!) }
    let order = model.timers.compactMap(\.entry.duration)
    expect(order == [30, 300, 600, 1200, 3600], "expected soonest-first order, got \(order)")
    model.removeAll()

    print(failures == 0 ? "All self-tests passed" : "\(failures) self-test failure(s)")
    return failures == 0
}
