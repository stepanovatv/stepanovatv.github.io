import Foundation
import SwiftUI
import ScheduleCore

@MainActor final class ScheduleViewModel: ObservableObject {
    @Published var schedule: Schedule?
    @Published var configuration: RepositoryConfiguration
    @Published var monday: String
    @Published var isWorking = false
    @Published var status = Texts.loading
    @Published var errorMessage: String?
    @Published var hasConflict = false
    @Published var showingSettings = false
    @Published private var history = EditHistory()
    private var remote: RemoteSchedule?
    private var syncedAt = Date()
    private let storage = LocalStorage()
    private let keychain = KeychainService()
    private var paintBefore: Schedule?
    private var paintValue = false
    private var visited = Set<String>()
    private var started = false

    init() {
        configuration = storage.configuration()
        monday = TimeZoneService.monday(containing: Date(), zone: TimeZone(identifier: "Asia/Yekaterinburg")!)
    }
    var isDirty: Bool { guard var value = schedule, let base = remote?.schedule else { return false }; value.updatedAt = base.updatedAt; return value != base }
    var canUndo: Bool { history.canUndo && !isWorking }
    var canRedo: Bool { history.canRedo && !isWorking }
    var canPublish: Bool { isDirty && !isWorking && paintBefore == nil }
    var dates: [String] { (0..<7).map { TimeZoneService.addDays(monday, $0) } }
    var syncLabel: String { let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.timeZone = schedule?.timeZone; f.dateFormat = "d MMMM, HH:mm"; return f.string(from: syncedAt) }

    func start() async {
        guard !started else { return }; started = true
        guard configuration.isValid else { status = "Приложение ещё не настроено. Попросите помочь с первым подключением."; return }
        do {
            if let cache = try storage.loadDraft(identity: configuration.identity) {
                remote = cache.remote; schedule = cache.draft; syncedAt = cache.syncedAt; today()
            }
        } catch { errorMessage = "Не удалось прочитать локальный черновик. Загружаем опубликованную версию." }
        await refresh()
    }
    func refresh(discardChanges: Bool = false) async {
        guard !isWorking, configuration.isValid else { return }
        isWorking = true; status = Texts.loading; defer { isWorking = false }
        do {
            let token = try keychain.read(account: configuration.identity)
            let latest = try await GitHubService(configuration: configuration).fetch(token: token)
            if isDirty && !discardChanges {
                if remote?.sha != latest.sha { hasConflict = true; status = Texts.conflict; return }
                syncedAt = Date(); status = Texts.dirty; cache(); return
            }
            let first = schedule == nil
            remote = latest; schedule = latest.schedule; syncedAt = Date(); history.reset(); hasConflict = false
            status = Texts.current; errorMessage = nil; if first { today() }; cache()
        } catch { errorMessage = error.localizedDescription; status = schedule == nil ? "Не удалось обновить расписание" : "Локальный черновик доступен для редактирования" }
    }
    func publish() async {
        guard canPublish, let schedule, let remote else { return }
        isWorking = true; status = Texts.publishing; errorMessage = nil; defer { isWorking = false }
        do {
            let token = try keychain.read(account: configuration.identity)
            let result = try await GitHubService(configuration: configuration).publish(schedule, expectedSHA: remote.sha, token: token)
            self.remote = result; self.schedule = result.schedule; syncedAt = Date(); hasConflict = false; status = Texts.published; cache()
        } catch GitHubError.conflict { hasConflict = true; status = Texts.conflict }
        catch { errorMessage = error.localizedDescription; status = Texts.dirty }
    }
    private func cache() {
        guard let schedule, let remote else { return }
        do { try storage.saveDraft(DraftSnapshot(identity: configuration.identity, remote: remote, draft: schedule, syncedAt: syncedAt)) }
        catch { errorMessage = error.localizedDescription }
    }
    private func changed() { status = isDirty ? Texts.dirty : Texts.current; cache() }
    func edit(_ action: (inout Schedule) -> Void) {
        guard !isWorking, var value = schedule else { return }; let before = value; action(&value)
        history.record(before: before, after: value); schedule = value; changed()
    }
    func toggle(date: String, time: String) { edit { $0.setBusy(!$0.isBusy(date: date, time: time), date: date, times: [time]) } }
    func setDay(_ date: String, busy: Bool) { edit { $0.setBusy(busy, date: date, times: $0.slotTimes) } }
    func setRange(date: String, start: String, end: String, busy: Bool) { edit { value in
        let times = value.slotTimes.filter { $0 >= start && $0 < end }; value.setBusy(busy, date: date, times: times)
    } }
    func copyWeek() { edit { $0.copyPreviousWeek(to: monday) } }
    func beginPaint(date: String, time: String) {
        guard !isWorking, paintBefore == nil, let schedule else { return }
        paintBefore = schedule; paintValue = !schedule.isBusy(date: date, time: time); visited.removeAll(); paint(date: date, time: time)
    }
    func paint(date: String, time: String) {
        guard paintBefore != nil, visited.insert(date + time).inserted else { return }
        schedule?.setBusy(paintValue, date: date, times: [time]); status = Texts.dirty
    }
    func endPaint() {
        guard let before = paintBefore, let schedule else { return }; paintBefore = nil
        history.record(before: before, after: schedule); visited.removeAll(); changed()
    }
    func undo() {
        guard canUndo, let current = schedule, let prior = history.undo(current: current) else { return }; schedule = prior; changed()
    }
    func redo() {
        guard canRedo, let current = schedule, let next = history.redo(current: current) else { return }; schedule = next; changed()
    }
    func moveWeek(_ delta: Int) {
        let next = TimeZoneService.addDays(monday, delta * 7)
        if next >= "1901-01-01", next <= "2099-12-20" { monday = next }
    }
    func today() { monday = TimeZoneService.monday(containing: Date(), zone: schedule?.timeZone ?? TimeZone(identifier: "Asia/Yekaterinburg")!) }
    func saveSettings(_ value: RepositoryConfiguration, token: String, removeToken: Bool) async -> Bool {
        guard !isWorking, value.isValid else { errorMessage = "Заполните параметры подключения и HTTPS-ссылку на расписание."; return false }
        do {
            if removeToken { try keychain.delete(account: value.identity) }
            else if !token.isEmpty { try keychain.save(token.trimmingCharacters(in: .whitespacesAndNewlines), account: value.identity) }
            try storage.saveConfiguration(value)
            let changedRepository = configuration.identity != value.identity
            configuration = value
            if changedRepository {
                schedule = nil; remote = nil; history.reset(); started = false; hasConflict = false; await start()
            } else { await refresh() }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}
