import Foundation

public struct DraftSnapshot: Codable, Sendable {
    public var identity: String
    public var remote: RemoteSchedule
    public var draft: Schedule
    public var syncedAt: Date
    public init(identity: String, remote: RemoteSchedule, draft: Schedule, syncedAt: Date) {
        self.identity = identity; self.remote = remote; self.draft = draft; self.syncedAt = syncedAt
    }
}

public struct EditHistory {
    private var undoStack: [Schedule] = []
    private var redoStack: [Schedule] = []
    public init() {}
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public mutating func record(before: Schedule, after: Schedule) {
        guard before != after else { return }; undoStack.append(before); redoStack.removeAll()
    }
    public mutating func undo(current: Schedule) -> Schedule? {
        guard let value = undoStack.popLast() else { return nil }; redoStack.append(current); return value
    }
    public mutating func redo(current: Schedule) -> Schedule? {
        guard let value = redoStack.popLast() else { return nil }; undoStack.append(current); return value
    }
    public mutating func reset() { undoStack.removeAll(); redoStack.removeAll() }
}
