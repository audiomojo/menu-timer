import Foundation

/// Reads a meeting dragged from Outlook. Outlook puts a text summary on the drag:
///
///     Pay Mom's Covington Bill
///     When: Friday, October 30, 2026 at 9:30 AM - 10:00 AM.
///     Location:
///
/// The text is used rather than the attached .ics because, for a recurring meeting, the .ics
/// describes the whole series (its first date), not the occurrence that was dragged.
enum OutlookMeeting {
    /// An alarm at the meeting's start, labeled with its subject; nil if the text isn't an
    /// Outlook meeting or the meeting has already started.
    static func entry(fromText text: String, now: Date = Date(), timeZone: TimeZone = .current) -> Entry? {
        // Outlook uses no-break spaces, e.g. before "AM".
        let lines = text.replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let subject = lines.first, !subject.isEmpty,
              let when = lines.first(where: { $0.hasPrefix("When:") }),
              let start = parseStart(String(when.dropFirst("When:".count)), timeZone: timeZone),
              start > now else { return nil }
        return Entry(kind: .alarm, end: start, label: subject)
    }

    /// "Friday, October 30, 2026 at 9:30 AM - 10:00 AM." → the start. All-day meetings have no time, so give nil.
    private static func parseStart(_ text: String, timeZone: TimeZone) -> Date? {
        let start = text.components(separatedBy: " - ").first?
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "."))) ?? ""
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["EEEE, MMMM d, yyyy 'at' h:mm a", "EEEE, MMMM d, yyyy h:mm a", "EEEE, MMMM d, yyyy 'at' HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: start) { return date }
        }
        return nil
    }
}
