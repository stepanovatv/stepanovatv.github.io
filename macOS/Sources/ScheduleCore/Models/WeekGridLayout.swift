import Foundation

/// Immutable labels and slot geometry, independent of busy/free edits.
/// Construct once per displayed week/configuration, never once per cell.
public final class WeekGridLayout: Sendable {
    public struct Key: Equatable, Sendable {
        public let monday: String
        public let sourceTimeZone: String
        public let dayStart: String
        public let dayEnd: String
        public let duration: Int
        public init(monday: String, schedule: Schedule) {
            self.monday = monday; sourceTimeZone = schedule.sourceTimeZone
            dayStart = schedule.dayStart; dayEnd = schedule.dayEnd; duration = schedule.slotDurationMinutes
        }
    }
    public struct Day: Identifiable, Equatable, Sendable {
        public let id: String
        public let weekday: String
        public let shortDate: String
        public let accessibilityLabel: String
    }
    public let key: Key
    public let days: [Day]
    public let slotTimes: [String]
    public let title: String

    public init(monday: String, schedule: Schedule) {
        key = Key(monday: monday, schedule: schedule)
        slotTimes = schedule.slotTimes
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func formatter(_ format: String, locale: String = "ru_RU") -> DateFormatter {
            let f = DateFormatter(); f.calendar = calendar; f.timeZone = calendar.timeZone
            f.locale = Locale(identifier: locale); f.dateFormat = format; return f
        }
        let iso = formatter("yyyy-MM-dd", locale: "en_US_POSIX")
        let weekday = formatter("EEE"), short = formatter("dd.MM"), full = formatter("EEEE, d MMMM")
        let first = iso.date(from: monday)!
        let dates = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: first)! }
        days = dates.map { Day(id: iso.string(from: $0), weekday: weekday.string(from: $0),
                              shortDate: short.string(from: $0), accessibilityLabel: full.string(from: $0)) }
        title = "\(formatter("d MMM").string(from: first)) — \(formatter("d MMM yyyy").string(from: dates[6]))"
    }
}
