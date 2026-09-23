import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: ScheduleViewModel?
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
    }
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

@main enum AvailabilityScheduleLauncher {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--verify-package") {
            // A headless packaging check: no editor, user draft, Keychain, or network.
            guard Bundle.main.bundleURL.pathExtension == "app",
                  let configuration = AppResources.configuration() else {
                print("ERROR: the application cannot load its packaged configuration")
                exit(1)
            }
            guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                  NSImage(contentsOf: iconURL) != nil else {
                print("ERROR: the application icon is missing or invalid")
                exit(1)
            }
            print("OK: packaged configuration for \(configuration.owner)/\(configuration.repository), branch \(configuration.branch)")
            return
        }
        AvailabilityScheduleApp.main()
    }
}

struct AvailabilityScheduleApp: App {
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
