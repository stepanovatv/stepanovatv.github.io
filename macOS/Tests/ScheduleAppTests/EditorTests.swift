import Foundation
import Testing
import ScheduleCore
@testable import ScheduleApp

@MainActor struct EditorTests {
    // No remote snapshot is attached and start() is never called: these editors
    // cannot write drafts, access Keychain, or make requests to the live repository.
    private func editor() -> ScheduleViewModel {
        let model = ScheduleViewModel()
        model.schedule = Schedule()
        model.monday = "2026-09-14"
        return model
    }

    @Test func paintAppliesOneStateAndUndoGroupsTheGesture() {
        let model = editor()
        let original = model.schedule!
        model.beginPaint(date: "2026-09-14", time: "09:00")
        model.paint(date: "2026-09-14", time: "09:30")
        model.paint(date: "2026-09-14", time: "10:00")
        model.paint(date: "2026-09-14", time: "09:30")
        model.endPaint()
        #expect(model.schedule!.days["2026-09-14"]?.busy == ["09:00", "09:30", "10:00"])
        #expect(model.canUndo)
        model.undo()
        #expect(model.schedule == original)
        #expect(!model.canUndo)
        model.redo()
        #expect(model.schedule!.days["2026-09-14"]?.busy.count == 3)
    }

    @Test func paintStartingOnBusyClearsEveryVisitedSlot() {
        let model = editor()
        model.schedule!.setBusy(true, date: "2026-09-14", times: ["09:00", "09:30"])
        let original = model.schedule!
        model.beginPaint(date: "2026-09-14", time: "09:00")
        model.paint(date: "2026-09-14", time: "09:30")
        model.paint(date: "2026-09-14", time: "10:00") // Already free stays free.
        model.endPaint()
        #expect(model.schedule!.days["2026-09-14"] == nil)
        model.undo()
        #expect(model.schedule == original)
    }

    @Test func paintCanCrossDaysAndProtectsUnvisitedSlots() {
        let model = editor()
        model.schedule!.setBusy(true, date: "2026-09-16", times: ["15:00"])
        model.beginPaint(date: "2026-09-14", time: "09:00")
        model.paint(date: "2026-09-15", time: "09:00")
        model.paint(date: "2026-09-16", time: "09:30")
        model.endPaint()
        #expect(model.schedule!.isBusy(date: "2026-09-14", time: "09:00"))
        #expect(model.schedule!.isBusy(date: "2026-09-15", time: "09:00"))
        #expect(model.schedule!.isBusy(date: "2026-09-16", time: "09:30"))
        #expect(model.schedule!.isBusy(date: "2026-09-16", time: "15:00"))
        #expect(!model.schedule!.isBusy(date: "2026-09-16", time: "10:00"))
    }

    @Test func rangeIsEndExclusiveAndUndoable() {
        let model = editor()
        model.setRange(date: "2026-09-14", start: "14:00", end: "17:30", busy: true)
        #expect(model.schedule!.days["2026-09-14"]?.busy.count == 7)
        #expect(!model.schedule!.isBusy(date: "2026-09-14", time: "17:30"))
        model.undo()
        #expect(model.schedule!.days.isEmpty)
        model.redo()
        #expect(model.schedule!.days["2026-09-14"]?.busy.count == 7)
    }

    @Test func editsAreBlockedDuringNetworkOperation() {
        let model = editor()
        let original = model.schedule
        model.isWorking = true
        model.toggle(date: "2026-09-14", time: "09:00")
        model.setDay("2026-09-14", busy: true)
        model.beginPaint(date: "2026-09-14", time: "09:00")
        model.paint(date: "2026-09-14", time: "09:30")
        model.endPaint()
        #expect(model.schedule == original)
    }
}
