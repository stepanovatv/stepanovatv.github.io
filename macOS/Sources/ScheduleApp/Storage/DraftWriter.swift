import Foundation
import ScheduleCore

/// Serial writes keep snapshots in order without blocking the main actor.
/// flush() is used before quitting; flushAsync() before changing repositories.
final class DraftWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.publicavailability.schedule.drafts", qos: .utility)
    private let save: @Sendable (DraftSnapshot) throws -> Void
    private var lastError: Error? // Accessed only on queue.

    init(save: @escaping @Sendable (DraftSnapshot) throws -> Void = { try LocalStorage().saveDraft($0) }) {
        self.save = save
    }

    func enqueue(_ snapshot: DraftSnapshot, completion: @escaping @Sendable (String?) -> Void = { _ in }) {
        queue.async {
            do { try self.save(snapshot); self.lastError = nil; completion(nil) }
            catch { self.lastError = error; completion(error.localizedDescription) }
        }
    }

    func flush() throws {
        try queue.sync { if let error = lastError { throw error } }
    }

    func flushAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                if let error = self.lastError { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
