import Foundation

public enum ScheduleError: Error, LocalizedError, Equatable {
    case invalidData
    public var errorDescription: String? { "Файл расписания повреждён или имеет неподдерживаемый формат." }
}

public struct ScheduleDay: Codable, Equatable, Sendable {
    public var busy: [String]
    public init(busy: [String] = []) { self.busy = busy }
}

public struct Schedule: Codable, Equatable, Sendable {
    public var version: Int
    public var sourceTimeZone: String
    public var slotDurationMinutes: Int
    public var dayStart: String
    public var dayEnd: String
    public var updatedAt: String
    public var days: [String: ScheduleDay]

    public init(version: Int = 1, sourceTimeZone: String = "Asia/Yekaterinburg", slotDurationMinutes: Int = 30,
                dayStart: String = "09:00", dayEnd: String = "22:00", updatedAt: String = "2026-09-17T00:00:00Z", days: [String: ScheduleDay] = [:]) {
        self.version = version; self.sourceTimeZone = sourceTimeZone; self.slotDurationMinutes = slotDurationMinutes
        self.dayStart = dayStart; self.dayEnd = dayEnd; self.updatedAt = updatedAt; self.days = days
    }

    public var timeZone: TimeZone { TimeZone(identifier: sourceTimeZone)! }
    public var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = timeZone; c.firstWeekday = 2; return c }
    public var slotTimes: [String] {
        guard let start = Self.minutes(dayStart), let end = Self.minutes(dayEnd), slotDurationMinutes > 0 else { return [] }
        return stride(from: start, to: end, by: slotDurationMinutes).map(Self.timeString)
    }
    public static func minutes(_ value: String) -> Int? {
        guard value.range(of: "^(?:[01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }; return parts[0] * 60 + parts[1]
    }
    public static func timeString(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    public static func timestamp(_ date: Date = Date()) -> String { ISO8601DateFormatter().string(from: date) }
    public static func parseTimestamp(_ value: String) -> Date? {
        let f = ISO8601DateFormatter(); if let date = f.date(from: value) { return date }
        f.formatOptions.insert(.withFractionalSeconds); return f.date(from: value)
    }

    public func validate() throws {
        guard version == 1, sourceTimeZone.contains("/") || sourceTimeZone == "UTC",
              TimeZone(identifier: sourceTimeZone) != nil,
              let start = Self.minutes(dayStart), let end = Self.minutes(dayEnd), start < end,
              (5...240).contains(slotDurationMinutes), (end - start) % slotDurationMinutes == 0,
              updatedAt.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$", options: .regularExpression) != nil,
              Self.parseTimestamp(updatedAt) != nil, TimeZoneService.validDate(String(updatedAt.prefix(10))), days.count <= 10000
        else { throw ScheduleError.invalidData }
        let allowed = Set(slotTimes)
        for (date, day) in days {
            guard TimeZoneService.validDate(date), Set(day.busy).count == day.busy.count,
                  day.busy.allSatisfy({ allowed.contains($0) }) else { throw ScheduleError.invalidData }
            for time in day.busy { _ = try TimeZoneService.instant(date: date, time: time, zone: timeZone) }
        }
    }

    public static func decode(_ data: Data) throws -> Schedule {
        do {
            // Reject unknown fields so private annotations cannot silently enter the public file.
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(json.keys) == Set(["version", "sourceTimeZone", "slotDurationMinutes", "dayStart", "dayEnd", "updatedAt", "days"]),
                  let days = json["days"] as? [String: [String: Any]], days.values.allSatisfy({ Set($0.keys) == ["busy"] })
            else { throw ScheduleError.invalidData }
            let value = try JSONDecoder().decode(Schedule.self, from: data); try value.validate(); return value
        } catch { throw ScheduleError.invalidData }
    }
    public func encoded() throws -> Data {
        try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self) + Data([10])
    }
    public func isBusy(date: String, time: String) -> Bool { days[date]?.busy.contains(time) ?? false }
    public mutating func setBusy(_ busy: Bool, date: String, times: [String]) {
        var values = Set(days[date]?.busy ?? [])
        if busy { values.formUnion(times) } else { values.subtract(times) }
        if values.isEmpty { days.removeValue(forKey: date) } else { days[date] = ScheduleDay(busy: values.sorted()) }
    }
    public mutating func copyPreviousWeek(to monday: String) {
        for i in 0..<7 {
            let target = TimeZoneService.addDays(monday, i), source = TimeZoneService.addDays(monday, i - 7)
            if let day = days[source], !day.busy.isEmpty { days[target] = day } else { days.removeValue(forKey: target) }
        }
    }
}
