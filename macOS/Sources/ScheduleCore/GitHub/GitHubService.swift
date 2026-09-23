import Foundation

public enum GitHubError: Error, LocalizedError, Equatable {
    case conflict, offline, unauthorized, notFound, invalidResponse, configuration, rejected(Int)
    public var errorDescription: String? {
        switch self {
        case .conflict: return "Расписание было изменено с другого устройства."
        case .offline: return "Нет соединения с GitHub. Проверьте интернет и попробуйте снова."
        case .unauthorized: return "Нет доступа к расписанию. Проверьте подключение в настройках разработчика."
        case .notFound: return "Расписание не найдено. Проверьте настройки подключения."
        case .invalidResponse: return "Не удалось прочитать ответ GitHub. Попробуйте снова."
        case .configuration: return "Подключение ещё не настроено."
        case .rejected(let code): return "GitHub не принял изменения (\(code)). Попробуйте снова позже."
        }
    }
}

public struct RemoteSchedule: Codable, Equatable, Sendable {
    public var schedule: Schedule
    public var sha: String
    public init(schedule: Schedule, sha: String) { self.schedule = schedule; self.sha = sha }
}

public struct GitHubService {
    public let configuration: RepositoryConfiguration
    public let session: URLSession
    public init(configuration: RepositoryConfiguration, session: URLSession = .shared) { self.configuration = configuration; self.session = session }

    private func request(method: String, token: String) throws -> URLRequest {
        guard configuration.isValid else { throw GitHubError.configuration }
        var url = URL(string: "https://api.github.com/repos")!
        for part in [configuration.owner, configuration.repository, "contents"] + configuration.schedulePath.split(separator: "/").map(String.init) {
            url.appendPathComponent(part)
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if method == "GET" { components.queryItems = [URLQueryItem(name: "ref", value: configuration.branch)] }
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = method; request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("PublicAvailabilitySchedule", forHTTPHeaderField: "User-Agent")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw GitHubError.offline }
        guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
        switch http.statusCode {
        case 200...299: return data
        case 409: throw GitHubError.conflict
        case 401, 403: throw GitHubError.unauthorized
        case 404: throw GitHubError.notFound
        default: throw GitHubError.rejected(http.statusCode)
        }
    }
    public func fetch(token: String) async throws -> RemoteSchedule {
        struct Content: Decodable { let sha: String; let encoding: String; let content: String }
        let data = try await send(request(method: "GET", token: token))
        guard let result = try? JSONDecoder().decode(Content.self, from: data), result.encoding == "base64", !result.sha.isEmpty,
              let decoded = Data(base64Encoded: result.content, options: .ignoreUnknownCharacters) else { throw GitHubError.invalidResponse }
        return RemoteSchedule(schedule: try Schedule.decode(decoded), sha: result.sha)
    }
    public func fetch(tokenProvider: () throws -> String) async throws -> RemoteSchedule {
        let token: String
        do { token = try tokenProvider() }
        catch {
            // A locked Keychain must not prevent reading a public schedule.
            // Nothing is changed in Keychain, and publishing still requires its token.
            let credentialError = error
            do { return try await fetch(token: "") }
            catch { throw credentialError }
        }
        return try await fetch(token: token)
    }
    public func publish(_ schedule: Schedule, expectedSHA: String, token: String, now: Date = Date()) async throws -> RemoteSchedule {
        guard !token.isEmpty else { throw GitHubError.unauthorized }
        guard !expectedSHA.isEmpty else { throw GitHubError.invalidResponse }
        try schedule.validate()
        let current = try await fetch(token: token)
        guard current.sha == expectedSHA else { throw GitHubError.conflict }
        var updated = schedule; updated.updatedAt = Schedule.timestamp(now)
        struct Update: Encodable { let message: String; let content: String; let branch: String; let sha: String }
        var req = try request(method: "PUT", token: token)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Update(message: "Update schedule — \(updated.updatedAt)", content: updated.encoded().base64EncodedString(), branch: configuration.branch, sha: expectedSHA))
        let data: Data
        do { data = try await send(req) }
        catch let error as GitHubError {
            // 422 may be a validation error or a race. Re-read to distinguish it.
            if error == .rejected(422), let latest = try? await fetch(token: token), latest.sha != expectedSHA { throw GitHubError.conflict }
            throw error
        }
        struct Result: Decodable { struct Content: Decodable { let sha: String }; let content: Content }
        guard let result = try? JSONDecoder().decode(Result.self, from: data), !result.content.sha.isEmpty else { throw GitHubError.invalidResponse }
        return RemoteSchedule(schedule: updated, sha: result.content.sha)
    }
}
