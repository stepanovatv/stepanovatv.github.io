import Foundation
import Testing
@testable import ScheduleCore

struct WeekGridLayoutTests {
    @Test func labelsCrossYearWithoutChangingSourceDates() {
        let layout = WeekGridLayout(monday: "2026-12-28", schedule: Schedule())
        #expect(layout.days.map(\.id) == ["2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"])
        #expect(layout.days[4].shortDate == "01.01")
        #expect(layout.days[4].accessibilityLabel.contains("января"))
        #expect(layout.title.contains("2027"))
        #expect(layout.slotTimes.count == 26)
        #expect(layout.slotTimes.last == "21:30")
    }

    @Test func geometryUsesConfiguredGridAndLeapDay() {
        var schedule = Schedule()
        schedule.dayStart = "10:15"; schedule.dayEnd = "11:15"; schedule.slotDurationMinutes = 15
        let layout = WeekGridLayout(monday: "2024-02-26", schedule: schedule)
        #expect(layout.days[3].id == "2024-02-29")
        #expect(layout.days.last?.id == "2024-03-03")
        #expect(layout.slotTimes == ["10:15", "10:30", "10:45", "11:00"])
    }
}
