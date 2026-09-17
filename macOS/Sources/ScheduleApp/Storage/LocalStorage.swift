import Foundation
import ScheduleCore

enum StorageError: Error, LocalizedError {
    case keychain, disk
    var errorDescription: String? {
        switch self {
        case .keychain: return "Не удалось открыть Связку ключей. Разрешите приложению доступ и попробуйте снова."
        case .disk: return "Не удалось сохранить черновик на этом Mac. Не закрывайте приложение до публикации."
        }
    }
}
struct LocalStorage {
    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PublicAvailabilitySchedule", isDirectory: true)
    }
    private func url(_ file: String) -> URL { directory.appendingPathComponent(file) }
    func configuration() -> RepositoryConfiguration {
        if let data = try? Data(contentsOf: url("configuration.json")), let config = try? JSONDecoder().decode(RepositoryConfiguration.self, from: data) { return config }
        if let url = Bundle.module.url(forResource: "repository-config", withExtension: "json"), let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(RepositoryConfiguration.self, from: data) { return config }
        return RepositoryConfiguration()
    }
    func saveConfiguration(_ config: RepositoryConfiguration) throws { try save(JSONEncoder().encode(config), file: "configuration.json") }
    private func draftFile(_ identity: String) -> String {
        // Reversible encoding avoids collisions between branches and nested paths.
        "draft-" + Data(identity.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-") + ".json"
    }
    func loadDraft(identity: String) throws -> DraftSnapshot? {
        let path = url(draftFile(identity)); guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let draft = try JSONDecoder().decode(DraftSnapshot.self, from: Data(contentsOf: path))
        guard draft.identity == identity, !draft.remote.sha.isEmpty else { throw ScheduleError.invalidData }
        try draft.draft.validate(); try draft.remote.schedule.validate(); return draft
    }
    func saveDraft(_ draft: DraftSnapshot) throws { try save(JSONEncoder().encode(draft), file: draftFile(draft.identity)) }
    private func save(_ data: Data, file: String) throws {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); try data.write(to: url(file), options: .atomic) }
        catch { throw StorageError.disk }
    }
}
