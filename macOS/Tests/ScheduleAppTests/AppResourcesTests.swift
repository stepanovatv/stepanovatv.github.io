import Foundation
import Testing
import ScheduleCore
@testable import ScheduleApp

struct AppResourcesTests {
    private func application(at root: URL) throws -> Bundle {
        let app = root.appendingPathComponent("Standalone.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "test.schedule.resources.\(UUID().uuidString)", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: app))
    }

    @Test func standaloneApplicationLoadsItsOwnConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try application(at: root)
        let resource = try #require(app.resourceURL).appendingPathComponent(AppResources.bundleName)
        try FileManager.default.createDirectory(at: resource, withIntermediateDirectories: true)
        let expected = RepositoryConfiguration(owner: "test-owner", repository: "isolated-repo", branch: "custom", pagesURL: "https://example.com/schedule.html")
        try JSONEncoder().encode(expected).write(to: resource.appendingPathComponent("repository-config.json"))
        #expect(AppResources.configuration(in: app) == expected)
    }

    @Test func missingResourceDoesNotUseBuildMachineOrCrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try application(at: root)
        #expect(AppResources.configuration(in: app) == nil)
    }

    @Test func invalidPackagedConfigurationDoesNotCrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try application(at: root)
        let resource = try #require(app.resourceURL).appendingPathComponent(AppResources.bundleName)
        try FileManager.default.createDirectory(at: resource, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: resource.appendingPathComponent("repository-config.json"))
        #expect(AppResources.configuration(in: app) == nil)
    }
}
