import Testing
import Foundation
@testable import ScheduleCore

struct ScheduleTests {
    @Test func testSerializationAndSlots() throws {
        var schedule = Schedule(); schedule.setBusy(true, date: "2026-09-21", times: ["09:00", "13:00"])
        #expect(try Schedule.decode(schedule.encoded()) == schedule)
        #expect(schedule.slotTimes.count == 26); #expect(schedule.slotTimes.first == "09:00"); #expect(schedule.slotTimes.last == "21:30")
        #expect(schedule.isBusy(date: "2026-09-21", time: "09:00")); #expect(!(schedule.isBusy(date: "2026-09-28", time: "09:00")))
        #expect(!(schedule.isBusy(date: "2026-09-21", time: "09:30")))
    }
    @Test func testConfiguredGrid() throws {
        let schedule = Schedule(slotDurationMinutes: 15, dayStart: "10:15", dayEnd: "11:15")
        try schedule.validate(); #expect(schedule.slotTimes == ["10:15", "10:30", "10:45", "11:00"])
    }
    @Test func testTimeZonesAndBoundaryDates() throws {
        let source = TimeZone(identifier: "Asia/Yekaterinburg")!
        let instant = try TimeZoneService.instant(date: "2026-09-23", time: "15:00", zone: source)
        #expect(Schedule.timestamp(instant) == "2026-09-23T10:00:00Z")
        for (date, expected) in [("2026-09-23", "2026-09-22"), ("2026-10-01", "2026-09-30"), ("2027-01-01", "2026-12-31")] {
            let value = try TimeZoneService.instant(date: date, time: "09:00", zone: source)
            #expect(TimeZoneService.dateKey(value, zone: TimeZone(identifier: "America/Los_Angeles")!) == expected)
        }
        let yearEnd = try TimeZoneService.instant(date: "2026-12-31", time: "21:30", zone: source)
        #expect(TimeZoneService.dateKey(yearEnd, zone: TimeZone(identifier: "Pacific/Auckland")!) == "2027-01-01")
    }
    @Test func testDSTAndCalendar() throws {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        #expect(Schedule.timestamp(try TimeZoneService.instant(date: "2026-03-28", time: "15:00", zone: zone)) == "2026-03-28T14:00:00Z")
        #expect(Schedule.timestamp(try TimeZoneService.instant(date: "2026-03-29", time: "15:00", zone: zone)) == "2026-03-29T13:00:00Z")
        #expect(throws: (any Error).self) { try TimeZoneService.instant(date: "2026-03-29", time: "02:30", zone: zone) }
        #expect(Schedule.timestamp(try TimeZoneService.instant(date: "2026-10-25", time: "02:30", zone: zone)) == "2026-10-25T00:30:00Z")
        #expect(TimeZoneService.addDays("2026-12-31", 1) == "2027-01-01")
        #expect(TimeZoneService.addDays("2024-02-28", 1) == "2024-02-29")
    }
    @Test func testBadJSON() throws {
        #expect(throws: (any Error).self) { try Schedule.decode(Data("{".utf8)) }
        var schedule = Schedule(); schedule.slotDurationMinutes = 0; #expect(throws: (any Error).self) { try schedule.validate() }
        schedule = Schedule(); schedule.days["2026-02-30"] = ScheduleDay(); #expect(throws: (any Error).self) { try schedule.validate() }
        schedule = Schedule(); schedule.days["2026-09-21"] = ScheduleDay(busy: ["09:00", "09:00"]); #expect(throws: (any Error).self) { try schedule.validate() }
        schedule = Schedule(); schedule.days["2026-09-21"] = ScheduleDay(busy: ["22:00"]); #expect(throws: (any Error).self) { try schedule.validate() }
        schedule = Schedule(); schedule.sourceTimeZone = "UTC+5"; #expect(throws: (any Error).self) { try schedule.validate() }
        var json = try JSONSerialization.jsonObject(with: Schedule().encoded()) as! [String: Any]; json["email"] = "private@example.com"
        #expect(throws: (any Error).self) { try Schedule.decode(JSONSerialization.data(withJSONObject: json)) }
    }
    @Test func testBulkEditUndoRedoAndCopyWeek() {
        var schedule = Schedule(); let original = schedule; var history = EditHistory()
        schedule.setBusy(true, date: "2026-09-21", times: schedule.slotTimes)
        history.record(before: original, after: schedule)
        #expect(schedule.days["2026-09-21"]?.busy.count == 26)
        let beforeUndo = schedule; schedule = history.undo(current: schedule)!
        #expect(schedule == original); schedule = history.redo(current: schedule)!; #expect(schedule == beforeUndo)
        schedule.copyPreviousWeek(to: "2026-09-28"); #expect(schedule.days["2026-09-28"] == schedule.days["2026-09-21"])
        schedule.setBusy(false, date: "2026-09-21", times: schedule.slotTimes); #expect(schedule.days["2026-09-21"] == nil)
    }
    @Test func testDraftRoundTrip() throws {
        let snapshot = DraftSnapshot(identity: "owner/repo/master/schedule.json", remote: RemoteSchedule(schedule: Schedule(), sha: "abc"), draft: Schedule(), syncedAt: Date())
        let restored = try JSONDecoder().decode(DraftSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(restored.remote == snapshot.remote); #expect(restored.draft == snapshot.draft)
    }
}
