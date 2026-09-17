import Foundation

public struct RepositoryConfiguration: Codable, Equatable, Sendable {
    public var owner: String
    public var repository: String
    public var branch: String
    public var schedulePath: String
    public var pagesURL: String
    public init(owner: String = "", repository: String = "", branch: String = "master", schedulePath: String = "schedule.json", pagesURL: String = "") {
        self.owner = owner; self.repository = repository; self.branch = branch; self.schedulePath = schedulePath; self.pagesURL = pagesURL
    }
    public var identity: String { "\(owner)/\(repository)/\(branch)/\(schedulePath)" }
    public var isValid: Bool {
        let safe = "^[A-Za-z0-9_.-]+$"
        return owner.range(of: safe, options: .regularExpression) != nil && repository.range(of: safe, options: .regularExpression) != nil
            && !branch.isEmpty && !branch.contains("\n") && !schedulePath.isEmpty && !schedulePath.hasPrefix("/")
            && !schedulePath.split(separator: "/").contains("..") && schedulePath.hasSuffix(".json")
            && URL(string: pagesURL)?.scheme == "https" && URL(string: pagesURL)?.host != nil
    }
}
