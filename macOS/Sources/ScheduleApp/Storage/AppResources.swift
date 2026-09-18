import Foundation
import ScheduleCore

enum AppResources {
    static let bundleName = "PublicAvailabilitySchedule_ScheduleApp.bundle"

    static func configuration(in application: Bundle = .main) -> RepositoryConfiguration? {
        // SwiftPM's generated Bundle.module accessor can fall back to an absolute
        // build-machine path. A distributed .app must use its own Resources only.
        guard let directory = application.resourceURL,
              let resources = Bundle(url: directory.appendingPathComponent(bundleName)),
              let url = resources.url(forResource: "repository-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(RepositoryConfiguration.self, from: data),
              value.isValid else { return nil }
        return value
    }
}
