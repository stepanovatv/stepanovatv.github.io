import Foundation

// Compares date/label preparation used by the grid before and after caching.
// This deliberately excludes SwiftUI layout, drawing, and disk I/O.
@main struct RenderingBenchmark {
    @inline(never) static func legacyLabels(_ monday: String, _ schedule: Schedule) -> Int {
        var count = 0
        for time in schedule.slotTimes {
            let dates = (0..<7).map { TimeZoneService.addDays(monday, $0) }
            for date in dates {
                count += TimeZoneService.display(date, format: "EEEE, d MMMM").utf8.count + time.utf8.count
                if schedule.isBusy(date: date, time: time) { count += 1 }
            }
        }
        return count
    }
    @inline(never) static func cachedLabels(_ layout: WeekGridLayout, _ schedule: Schedule) -> Int {
        var count = 0
        for time in layout.slotTimes {
            for day in layout.days {
                count += day.accessibilityLabel.utf8.count + time.utf8.count
                if schedule.isBusy(date: day.id, time: time) { count += 1 }
            }
        }
        return count
    }
    static func measure(_ name: String, iterations: Int, _ run: (Int) -> Int) {
        let start = DispatchTime.now().uptimeNanoseconds
        var checksum = 0
        for i in 0..<iterations { checksum += run(i) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / Double(iterations)
        print(String(format: "%@: %.3f ms / iteration (checksum %d)", name, ms, checksum))
    }
    static func main() {
        let schedule = Schedule()
        let weeks = (0..<20).map { TimeZoneService.addDays("2026-09-14", $0 * 7) }
        let cached = WeekGridLayout(monday: weeks[0], schedule: schedule)
        _ = legacyLabels(weeks[0], schedule); _ = cachedLabels(cached, schedule)
        measure("Before: new week labels", iterations: 20) { legacyLabels(weeks[$0], schedule) }
        measure("After: new week labels", iterations: 20) {
            cachedLabels(WeekGridLayout(monday: weeks[$0], schedule: schedule), schedule)
        }
        measure("After: reuse labels for slot edit", iterations: 1000) { _ in cachedLabels(cached, schedule) }
    }
}
