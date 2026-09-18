import SwiftUI
import ScheduleCore

struct ContentView: View {
    @ObservedObject var model: ScheduleViewModel
    @Environment(\.openURL) private var openURL
    @State private var showRange = false
    @State private var confirmReload = false
    @State private var confirmCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(24)
            Divider()
            if let schedule = model.schedule {
                ScheduleGrid(model: model, schedule: schedule).padding(.horizontal, 14)
            } else {
                VStack(spacing: 18) {
                    if model.isWorking { ProgressView() }
                    Image(systemName: "calendar").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text(model.status).multilineTextAlignment(.center)
                    if !model.isWorking {
                        Button("Обновить расписание") { Task { await model.refresh() } }.disabled(!model.configuration.isValid)
                        Button("Настроить подключение") { model.showingSettings = true }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
            }
            Divider()
            footer.padding(20)
        }
        .frame(minWidth: 850, minHeight: 580)
        .tint(Color(red: 0.03, green: 0.51, blue: 0.28))
        .sheet(isPresented: $model.showingSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showRange) { if let schedule = model.schedule { RangeEditor(model: model, schedule: schedule) } }
        .alert(Texts.conflict, isPresented: $model.hasConflict) {
            Button("Загрузить актуальную версию", role: .destructive) { Task { await model.refresh(discardChanges: true) } }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Загрузка актуальной версии заменит ваш локальный черновик. При отмене изменения останутся в редакторе.") }
        .confirmationDialog("Загрузить опубликованную версию?", isPresented: $confirmReload) {
            Button("Заменить локальные изменения", role: .destructive) { Task { await model.refresh(discardChanges: true) } }
        } message: { Text("Неопубликованные изменения будут заменены версией с сайта.") }
        .confirmationDialog("Копировать предыдущую неделю?", isPresented: $confirmCopy) {
            Button("Копировать") { model.copyWeek() }
        } message: { Text("Слоты текущей недели будут заменены. Действие можно отменить через ⌘Z.") }
        .task { await model.start() }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Texts.title).font(.system(size: 26, weight: .semibold))
                    Text(model.schedule?.sourceTimeZone == "Asia/Yekaterinburg" || model.schedule == nil ? "Время Оренбурга · Asia/Yekaterinburg" : "Часовая зона расписания · \(model.schedule!.sourceTimeZone)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await model.publish() } } label: {
                    Label(model.isWorking ? "Подождите…" : Texts.publish, systemImage: "arrow.up.circle.fill")
                        .padding(.vertical, 7).padding(.horizontal, 4)
                }.buttonStyle(.borderedProminent).disabled(!model.canPublish).keyboardShortcut("s", modifiers: .command)
            }
            HStack(spacing: 12) {
                Button { model.moveWeek(-1) } label: { Image(systemName: "chevron.left") }.help("Предыдущая неделя")
                Text(model.weekTitle)
                    .font(.headline).frame(minWidth: 220)
                Button { model.moveWeek(1) } label: { Image(systemName: "chevron.right") }.help("Следующая неделя")
                Button("Сегодня") { model.today() }
                Spacer()
                Menu {
                    Button("Изменить диапазон…") { showRange = true }
                    Button("Копировать предыдущую неделю…") { confirmCopy = true }
                    Divider()
                    Button("Загрузить опубликованную версию…") {
                        if model.isDirty { confirmReload = true } else { Task { await model.refresh() } }
                    }
                } label: { Label("Действия", systemImage: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
            }.disabled(model.isWorking || model.schedule == nil)
        }
    }
    private var footer: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Text(model.isDirty && !model.isWorking && model.status != Texts.conflict ? Texts.dirty : model.status).font(.callout.weight(.medium))
                }
                if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
                else if model.status == Texts.published { Text(Texts.publishNote).font(.caption).foregroundStyle(.secondary) }
                else if model.schedule != nil { Text("Синхронизация: \(model.syncLabel) · Проведите мышью по окнам для группового изменения").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Button("Открыть расписание") { if let url = URL(string: model.configuration.pagesURL) { openURL(url) } }
                .disabled(!model.configuration.isValid)
        }
    }
}
