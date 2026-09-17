import Testing
import Foundation
@testable import ScheduleCore

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct GitHubTests {
    func service(branch: String = "master") -> GitHubService {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]
        return GitHubService(configuration: RepositoryConfiguration(owner: "teacher", repository: "schedule", branch: branch, schedulePath: "docs/schedule.json", pagesURL: "https://teacher.github.io/schedule/"), session: URLSession(configuration: config))
    }
    func content(sha: String = "original", schedule: Schedule = Schedule()) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["sha": sha, "encoding": "base64", "content": schedule.encoded().base64EncodedString()])
    }
    func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }; stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)) }
        return data
    }
    @Test func testGETUsesConfiguredRef() async throws {
        StubProtocol.handler = { req in
            #expect(req.url?.path == "/repos/teacher/schedule/contents/docs/schedule.json")
            #expect(URLComponents(url: req.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "release/week")
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return (200, try self.content())
        }
        let result = try await service(branch: "release/week").fetch(token: "test-token"); #expect(result.sha == "original")
    }
    @Test func testSuccessfulPublishChecksAndSendsSHA() async throws {
        var calls: [String] = []
        StubProtocol.handler = { req in
            calls.append(req.httpMethod!)
            if req.httpMethod == "GET" { return (200, try self.content()) }
            let json = try JSONSerialization.jsonObject(with: self.body(req)) as! [String: String]
            #expect(json["branch"] == "master"); #expect(json["sha"] == "original")
            let value = try Schedule.decode(Data(base64Encoded: json["content"]!)!); #expect(value.updatedAt == "2026-09-17T10:30:00Z")
            return (200, Data("{\"content\":{\"sha\":\"new\"}}".utf8))
        }
        let result = try await service().publish(Schedule(), expectedSHA: "original", token: "test-token", now: Schedule.parseTimestamp("2026-09-17T10:30:00Z")!)
        #expect(result.sha == "new"); #expect(calls == ["GET", "PUT"])
    }
    @Test func testPreflightConflictNeverWrites() async throws {
        StubProtocol.handler = { req in #expect(req.httpMethod == "GET"); return (200, try self.content(sha: "changed")) }
        do { _ = try await service().publish(Schedule(), expectedSHA: "original", token: "test-token"); Issue.record("Conflict expected") }
        catch { #expect(error as? GitHubError == .conflict) }
    }
    @Test func testRaceConflict409() async throws {
        StubProtocol.handler = { req in req.httpMethod == "GET" ? (200, try self.content()) : (409, Data()) }
        do { _ = try await service().publish(Schedule(), expectedSHA: "original", token: "test-token"); Issue.record("Conflict expected") }
        catch { #expect(error as? GitHubError == .conflict) }
    }
    @Test func test422RaceVsValidation() async throws {
        var reads = 0
        StubProtocol.handler = { req in
            if req.httpMethod == "PUT" { return (422, Data()) }
            reads += 1; return (200, try self.content(sha: reads == 1 ? "original" : "changed"))
        }
        do { _ = try await service().publish(Schedule(), expectedSHA: "original", token: "test-token"); Issue.record("Unexpected result") }
        catch { #expect(error as? GitHubError == .conflict) }
        StubProtocol.handler = { req in req.httpMethod == "GET" ? (200, try self.content()) : (422, Data()) }
        do { _ = try await service().publish(Schedule(), expectedSHA: "original", token: "test-token"); Issue.record("Unexpected result") }
        catch { #expect(error as? GitHubError == .rejected(422)) }
    }
    @Test func testOfflineUnauthorizedAndMalformedResponse() async throws {
        StubProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await service().fetch(token: ""); Issue.record("Unexpected result") } catch { #expect(error as? GitHubError == .offline) }
        StubProtocol.handler = { _ in (401, Data()) }
        do { _ = try await service().fetch(token: ""); Issue.record("Unexpected result") } catch { #expect(error as? GitHubError == .unauthorized) }
        StubProtocol.handler = { _ in (200, Data("{}".utf8)) }
        do { _ = try await service().fetch(token: ""); Issue.record("Unexpected result") } catch { #expect(error as? GitHubError == .invalidResponse) }
    }
    @Test func testInvalidSchedulePreventsNetwork() async throws {
        StubProtocol.handler = { _ in Issue.record("Must not call GitHub"); return (500, Data()) }
        var invalid = Schedule(); invalid.version = 9
        do { _ = try await service().publish(invalid, expectedSHA: "original", token: "test-token"); Issue.record("Unexpected result") }
        catch { #expect(error as? ScheduleError == .invalidData) }
    }
}
