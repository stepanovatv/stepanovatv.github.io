import SwiftUI
import ScheduleCore

struct ContentView: View {
    @ObservedObject var model: ScheduleViewModel
    @Environment(\.openURL) private var openURL
    @State private var showRange = false
    @State private var confirmReload = false
    @State private var confirmCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header.padding(20).schedulePanel()
            if let schedule = model.schedule {
                ScheduleGrid(model: model, schedule: schedule)
                    .padding(.horizontal, 10).padding(.bottom, 8)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.black.opacity(0.045), lineWidth: 1))
                    .shadow(color: ScheduleAppearance.shadow, radius: 10, x: 0, y: 4)
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
            footer.padding(16).schedulePanel()
        }
        .padding(16)
        .frame(minWidth: 850, minHeight: 580)
        .background(ScheduleAppearance.background)
        .scheduleControls()
        .preferredColorScheme(.light)
        .tint(ScheduleAppearance.accent)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Texts.title).font(.system(size: 26, weight: .semibold))
                    Text(model.schedule?.sourceTimeZone == "Asia/Yekaterinburg" || model.schedule == nil ? "Время Оренбурга · Asia/Yekaterinburg" : "Часовая зона расписания · \(model.schedule!.sourceTimeZone)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await model.publish() } } label: {
                    ScheduleActionLabel(title: model.isWorking ? "Подождите…" : Texts.publish, icon: "arrow.up.circle")
                }.scheduleControls(prominent: true).tint(ScheduleAppearance.accent).controlSize(.large).disabled(!model.canPublish).keyboardShortcut("s", modifiers: .command)
            }
            HStack(spacing: 12) {
                Button { model.moveWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 20, height: 26) }.help("Предыдущая неделя")
                Text(model.weekTitle)
                    .font(.headline).frame(minWidth: 220)
                Button { model.moveWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 20, height: 26) }.help("Следующая неделя")
                Button { model.today() } label: { Text("Сегодня").padding(.horizontal, 6).frame(height: 26) }
                Spacer()
                HStack(spacing: 8) {
                    actionButton(Texts.editRange, icon: "slider.horizontal.3") { showRange = true }
                    actionButton(Texts.copyWeek, icon: "doc.on.doc") { confirmCopy = true }
                    Divider().frame(height: 22).padding(.horizontal, 2)
                    actionButton(Texts.reload, icon: "arrow.clockwise") {
                        if model.isDirty { confirmReload = true } else { Task { await model.refresh() } }
                    }
                }
            }.disabled(model.isWorking || model.schedule == nil)
        }
    }
    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .medium)).frame(width: 30, height: 28)
        }
        .scheduleControls().help(title).accessibilityLabel(title)
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
            Button { if let url = URL(string: model.configuration.pagesURL) { openURL(url) } } label: {
                ScheduleActionLabel(title: "Открыть расписание", icon: "arrow.up.right.square")
            }
                .scheduleControls().controlSize(.large)
                .disabled(!model.configuration.isValid)
        }
    }
}
