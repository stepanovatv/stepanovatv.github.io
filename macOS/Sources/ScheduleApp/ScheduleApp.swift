import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: ScheduleViewModel?
    @MainActor func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if model.isWorking {
            let alert = NSAlert(); alert.messageText = "Дождитесь завершения синхронизации"; alert.informativeText = "Это займёт несколько секунд."; alert.runModal(); return .terminateCancel
        }
        model.endPaint()
        do { try model.flushDrafts() }
        catch {
            let alert = NSAlert(); alert.messageText = "Черновик не сохранён"
            alert.informativeText = error.localizedDescription; alert.runModal(); return .terminateCancel
        }
        guard model.isDirty else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "Есть неопубликованные изменения"
        alert.informativeText = "Черновик сохранён на этом Mac. Чтобы изменения появились на сайте, вернитесь в приложение и нажмите «Опубликовать расписание»."
        alert.addButton(withTitle: "Продолжить редактирование"); alert.addButton(withTitle: "Закрыть с черновиком")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main struct AvailabilityScheduleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = ScheduleViewModel()
    var body: some Scene {
        Window(Texts.title, id: "schedule") {
            ContentView(model: model).onAppear { delegate.model = model }
        }
        .defaultSize(width: 1100, height: 850)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Отменить") { model.undo() }.keyboardShortcut("z", modifiers: .command).disabled(!model.canUndo)
                Button("Повторить") { model.redo() }.keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!model.canRedo)
            }
            CommandGroup(after: .appSettings) {
                Button(Texts.developerSettings + "…") { model.showingSettings = true }
                    .keyboardShortcut(",", modifiers: [.command, .option]).disabled(model.isWorking)
            }
            CommandMenu("Расписание") {
                Button("Предыдущая неделя") { model.moveWeek(-1) }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Следующая неделя") { model.moveWeek(1) }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Сегодня") { model.today() }.keyboardShortcut("t", modifiers: .command)
                Button("Обновить расписание") { Task { await model.refresh() } }.keyboardShortcut("r", modifiers: .command).disabled(model.isWorking)
            }
        }
    }
}
