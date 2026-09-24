import SwiftUI
import ScheduleCore

struct SettingsView: View {
    @ObservedObject var model: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var config: RepositoryConfiguration
    @State private var token = ""
    @State private var removeToken = false
    @State private var saving = false
    init(model: ScheduleViewModel) { self.model = model; _config = State(initialValue: model.configuration) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Texts.developerSettings).font(.title2.bold())
            Text("Первичное подключение. Для повседневной работы этот раздел не нужен.").foregroundStyle(.secondary)
            Form {
                TextField("GitHub owner", text: $config.owner)
                TextField("GitHub repository", text: $config.repository)
                TextField("GitHub branch", text: $config.branch)
                TextField("Путь к schedule.json", text: $config.schedulePath)
                TextField("GitHub Pages URL", text: $config.pagesURL)
                SecureField("Новый Personal Access Token", text: $token)
                Toggle("Удалить сохранённый token", isOn: $removeToken)
            }
            Text("Fine-grained token: только этот repository, Contents → Read and write. Пустое поле сохраняет существующий token. Хранение — только в macOS Keychain.")
                .font(.caption).foregroundStyle(.secondary)
            if model.isDirty { Text("Неопубликованные изменения останутся в локальном черновике текущего подключения.").font(.caption) }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red).font(.callout) }
            HStack { Spacer(); Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(saving ? "Подключаем…" : "Сохранить и подключить") {
                    saving = true
                    Task { let success = await model.saveSettings(config, token: token, removeToken: removeToken); token = ""; saving = false; if success { dismiss() } }
                }.scheduleControls(prominent: true).keyboardShortcut(.defaultAction).disabled(!config.isValid || saving || model.isWorking)
            }
        }.padding(26).frame(width: 580).disabled(saving)
            .background(ScheduleAppearance.background).scheduleControls().tint(ScheduleAppearance.accent)
    }
}
