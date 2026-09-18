import Foundation
import Testing
import ScheduleCore
@testable import ScheduleApp

private final class SavedDrafts: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ value: String) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    func all() -> [String] { lock.lock(); defer { lock.unlock() }; return values }
}

struct DraftWriterTests {
    private func snapshot(_ identity: String) -> DraftSnapshot {
        DraftSnapshot(identity: identity, remote: RemoteSchedule(schedule: Schedule(), sha: "test-sha"), draft: Schedule(), syncedAt: Date())
    }

    @Test @MainActor func enqueueDoesNotBlockUIAndFlushPreservesOrder() throws {
        let gate = DispatchSemaphore(value: 0)
        let saved = SavedDrafts()
        let writer = DraftWriter { snapshot in
            #expect(!Thread.isMainThread)
            if snapshot.identity == "first" {
                #expect(gate.wait(timeout: .now() + 2) == .success)
            }
            saved.append(snapshot.identity)
        }
        writer.enqueue(snapshot("first"))
        writer.enqueue(snapshot("second"))
        // This line can execute while a disk write is blocked on the background queue.
        gate.signal()
        try writer.flush()
        #expect(saved.all() == ["first", "second"])
    }

    @Test func failedWriteIsReportedAndLaterSuccessRecovers() async throws {
        let writer = DraftWriter { snapshot in
            if snapshot.identity == "failure" { throw StorageError.disk }
        }
        writer.enqueue(snapshot("failure"))
        #expect(throws: StorageError.self) { try writer.flush() }
        do { try await writer.flushAsync(); Issue.record("Expected pending disk error") }
        catch { #expect(error is StorageError) }
        writer.enqueue(snapshot("recovered"))
        try await writer.flushAsync()
        try writer.flush()
    }
}
