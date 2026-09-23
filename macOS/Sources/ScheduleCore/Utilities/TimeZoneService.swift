import Foundation

public enum TimeZoneService {
    /// Weekday of a source calendar date, independent of the computer's timezone.
    /// Numeric components avoid creating date formatters for every grid cell.
    public static func isoWeekday(_ value: String) -> Int {
        let numbers = value.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return 0 }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])) else { return 0 }
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
    private static func dateFormatter(zone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f
    }
    public static func validDate(_ value: String) -> Bool {
        guard value.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil,
              value >= "1900-01-01", value <= "2100-12-31", let date = dateFormatter().date(from: value) else { return false }
        return dateFormatter().string(from: date) == value
    }
    public static func dateKey(_ date: Date, zone: TimeZone) -> String { dateFormatter(zone: zone).string(from: date) }
    public static func addDays(_ value: String, _ days: Int) -> String {
        let f = dateFormatter(); var c = Calendar(identifier: .gregorian); c.timeZone = f.timeZone
        return f.string(from: c.date(byAdding: .day, value: days, to: f.date(from: value)!)!)
    }
    public static func monday(containing date: Date, zone: TimeZone) -> String {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone
        return addDays(dateKey(date, zone: zone), -((c.component(.weekday, from: date) + 5) % 7))
    }
    public static func instant(date: String, time: String, zone: TimeZone) throws -> Date {
        guard validDate(date), let minutes = Schedule.minutes(time) else { throw ScheduleError.invalidData }
        let numbers = date.split(separator: "-").compactMap { Int($0) }
        var c = Calendar(identifier: .gregorian); c.timeZone = zone
        let components = DateComponents(timeZone: zone, year: numbers[0], month: numbers[1], day: numbers[2], hour: minutes / 60, minute: minutes % 60, second: 0)
        let anchor = dateFormatter().date(from: date)!.addingTimeInterval(-36 * 3600)
        guard let value = c.nextDate(after: anchor, matching: components, matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward),
              dateKey(value, zone: zone) == date else { throw ScheduleError.invalidData }
        return value
    }
    public static func display(_ date: String, format: String) -> String {
        let f = dateFormatter(); let value = f.date(from: date)!; f.locale = Locale(identifier: "ru_RU"); f.dateFormat = format
        return f.string(from: value)
    }
}
