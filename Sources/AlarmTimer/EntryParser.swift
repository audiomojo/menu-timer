import Foundation

struct Entry: Equatable {
    enum Kind { case timer, alarm }
    let kind: Kind
    let end: Date
    /// Text typed after the time, e.g. "Flip Pancakes" in "5m Flip Pancakes".
    var label = ""
}

enum EntryParser {
    /// Parses "5m", "1h30m", "90s", "20" (minutes) as timers and
    /// "9:30am", "2pm", "14:30", "9:30" (next occurrence) as alarms.
    /// Anything after the time, separated by a space, becomes the label.
    static func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> Entry? {
        let words = raw.split(whereSeparator: \.isWhitespace)
        // Longest leading run of words that reads as a time wins, so "1h 30m Tea" keeps "30m" in the time.
        for count in stride(from: words.count, through: 1, by: -1) {
            if var entry = parseTime(words[..<count].joined(separator: " "), now: now, calendar: calendar) {
                entry.label = words[count...].joined(separator: " ")
                return entry
            }
        }
        return nil
    }

    private static func parseTime(_ raw: String, now: Date, calendar: Calendar) -> Entry? {
        let text = raw.lowercased().filter { !$0.isWhitespace }
        guard !text.isEmpty else { return nil }

        if let seconds = duration(text) {
            guard seconds >= 1 else { return nil }
            return Entry(kind: .timer, end: now.addingTimeInterval(seconds))
        }
        if let end = clockTime(text, now: now, calendar: calendar) {
            return Entry(kind: .alarm, end: end)
        }
        return nil
    }

    private static func duration(_ text: String) -> TimeInterval? {
        if let minutes = Double(text), text.first?.isNumber == true, minutes.isFinite {
            return minutes * 60
        }
        let pattern = #/^(?:(\d+(?:\.\d+)?)(?:hours|hour|hrs|hr|h))?(?:(\d+(?:\.\d+)?)(?:minutes|minute|mins|min|m))?(?:(\d+(?:\.\d+)?)(?:seconds|second|secs|sec|s))?$/#
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        let (_, h, m, s) = match.output
        guard h != nil || m != nil || s != nil else { return nil }
        func value(_ part: Substring?) -> Double { part.flatMap { Double($0) } ?? 0 }
        return value(h) * 3600 + value(m) * 60 + value(s)
    }

    private static func clockTime(_ text: String, now: Date, calendar: Calendar) -> Date? {
        var hours: [Int]
        let minute: Int

        if let match = text.wholeMatch(of: #/^(\d{1,2})(?::(\d{2}))?\.?(a|p)\.?m?\.?$/#) {
            let (_, h, m, meridiem) = match.output
            guard let hour = Int(h), (1...12).contains(hour) else { return nil }
            minute = m.flatMap { Int($0) } ?? 0
            hours = [hour % 12 + (meridiem == "p" ? 12 : 0)]
        } else if let match = text.wholeMatch(of: #/^(\d{1,2}):(\d{2})$/#) {
            let (_, h, m) = match.output
            guard let hour = Int(h), hour < 24 else { return nil }
            minute = Int(m) ?? 0
            // Without am/pm, 1–12 is ambiguous: take whichever comes next.
            hours = (1...12).contains(hour) ? [hour % 12, hour % 12 + 12] : [hour]
        } else {
            return nil
        }
        guard minute < 60 else { return nil }

        return hours.compactMap {
            calendar.nextDate(after: now,
                              matching: DateComponents(hour: $0, minute: minute, second: 0),
                              matchingPolicy: .nextTime)
        }.min()
    }
}

func formatCountdown(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
