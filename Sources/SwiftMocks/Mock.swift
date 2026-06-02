import Foundation

// The call trackers backing a generated Mock Type. One tracker is generated per mocked
// member; the Stub Surface configures it and the Verify Surface reads it. Trackers are
// reference types so both facades observe the same recorded state.
//
// There is one tracker per Effect Signature:
//   Mock              — sync, non-throwing
//   ThrowingMock      — sync, throwing
//   AsyncMock         — async, non-throwing
//   AsyncThrowingMock — async, throwing
//
// A stub closure carries the same effects as the member it stubs.
//
// Concurrency: trackers are `@unchecked Sendable` and guard their mutable state with a
// lock so a mock can cross actor/task boundaries (routine for async members) without data
// races. The lock is held only to *select* a behaviour and append history — never across
// the invocation of a stub body, so an `async` stub never suspends while holding the lock.

/// Recorded-call history shared by every tracker. The Verify Surface reads through this.
public class CallTracker<Args>: @unchecked Sendable {
    let lock = NSLock()
    private var history: [Args] = []

    func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Appends a call. Caller must hold `lock`.
    func recordLocked(_ args: Args) { history.append(args) }

    public var callsHistory: [Args] { withLock { history } }
    public var callsCount: Int { withLock { history.count } }
    public var hasBeenCalled: Bool { withLock { !history.isEmpty } }
    public var neverCalled: Bool { withLock { history.isEmpty } }
    public var calledOnce: Bool { withLock { history.count == 1 } }
    public var latestCall: Args? { withLock { history.last } }

    /// Number of recorded calls whose arguments satisfy `predicate`.
    public func callCount(where predicate: (Args) -> Bool) -> Int {
        withLock { history.lazy.filter(predicate).count }
    }

    /// Whether any recorded call's arguments satisfy `predicate`.
    public func called(where predicate: (Args) -> Bool) -> Bool {
        withLock { history.contains(where: predicate) }
    }
}

// MARK: - sync, non-throwing

public final class Mock<Args, Return>: CallTracker<Args>, @unchecked Sendable {
    private var conditional: [(check: (Args) -> Bool, body: (Args) -> Return)] = []
    private var fallback: ((Args) -> Return)?
    private var sequence: [Return]?
    private var sequenceIndex = 0
    private let fallbackDefault: ((Args) -> Return)?
    private let member: String

    public init(_ member: String = "function") {
        self.fallbackDefault = nil
        self.member = member
    }

    public init(_ member: String = "function", default value: @escaping @autoclosure () -> Return) {
        self.fallbackDefault = { _ in value() }
        self.member = member
    }

    public func setStub(_ body: @escaping (Args) -> Return) { withLock { fallback = body; sequence = nil } }

    public func setStub(when check: @escaping (Args) -> Bool, _ body: @escaping (Args) -> Return) {
        withLock { conditional.append((check, body)) }
    }

    public func setSequence(_ values: [Return]) {
        withLock { sequence = values.isEmpty ? nil : values; sequenceIndex = 0; if !values.isEmpty { fallback = nil } }
    }

    public func record(_ args: Args, file: StaticString = #filePath, line: UInt = #line) -> Return {
        let behavior: (Args) -> Return = withLock {
            recordLocked(args)
            if let stub = conditional.first(where: { $0.check(args) }) { return stub.body }
            if let fallback { return fallback }
            if let sequence { let v = nextInSequence(sequence); return { _ in v } }
            if let fallbackDefault { return fallbackDefault }
            return { _ in SwiftMocks.unstubbed(self.member, file: file, line: line) }
        }
        return behavior(args)
    }

    /// Resolves the next sequence value. Caller must hold `lock`.
    private func nextInSequence(_ values: [Return]) -> Return {
        let value = values[min(sequenceIndex, values.count - 1)]
        if sequenceIndex < values.count - 1 { sequenceIndex += 1 }
        return value
    }
}

// MARK: - sync, throwing

public final class ThrowingMock<Args, Return>: CallTracker<Args>, @unchecked Sendable {
    private var conditional: [(check: (Args) -> Bool, body: (Args) throws -> Return)] = []
    private var fallback: ((Args) throws -> Return)?
    private var sequence: [Return]?
    private var sequenceIndex = 0
    private let fallbackDefault: ((Args) -> Return)?
    private let member: String

    public init(_ member: String = "function") {
        self.fallbackDefault = nil
        self.member = member
    }

    public init(_ member: String = "function", default value: @escaping @autoclosure () -> Return) {
        self.fallbackDefault = { _ in value() }
        self.member = member
    }

    public func setStub(_ body: @escaping (Args) throws -> Return) { withLock { fallback = body; sequence = nil } }

    public func setStub(when check: @escaping (Args) -> Bool, _ body: @escaping (Args) throws -> Return) {
        withLock { conditional.append((check, body)) }
    }

    public func setError(_ error: Error) { withLock { fallback = { _ in throw error }; sequence = nil } }

    public func setSequence(_ values: [Return]) {
        withLock { sequence = values.isEmpty ? nil : values; sequenceIndex = 0; if !values.isEmpty { fallback = nil } }
    }

    public func record(_ args: Args, file: StaticString = #filePath, line: UInt = #line) throws -> Return {
        let behavior: (Args) throws -> Return = withLock {
            recordLocked(args)
            if let stub = conditional.first(where: { $0.check(args) }) { return stub.body }
            if let fallback { return fallback }
            if let sequence { let v = nextInSequence(sequence); return { _ in v } }
            if let fallbackDefault { return fallbackDefault }
            return { _ in SwiftMocks.unstubbed(self.member, file: file, line: line) }
        }
        return try behavior(args)
    }

    private func nextInSequence(_ values: [Return]) -> Return {
        let value = values[min(sequenceIndex, values.count - 1)]
        if sequenceIndex < values.count - 1 { sequenceIndex += 1 }
        return value
    }
}

// MARK: - async, non-throwing

public final class AsyncMock<Args, Return>: CallTracker<Args>, @unchecked Sendable {
    private var conditional: [(check: (Args) -> Bool, body: (Args) async -> Return)] = []
    private var fallback: ((Args) async -> Return)?
    private var sequence: [Return]?
    private var sequenceIndex = 0
    private let fallbackDefault: ((Args) -> Return)?
    private let member: String

    public init(_ member: String = "function") {
        self.fallbackDefault = nil
        self.member = member
    }

    public init(_ member: String = "function", default value: @escaping @autoclosure () -> Return) {
        self.fallbackDefault = { _ in value() }
        self.member = member
    }

    public func setStub(_ body: @escaping (Args) async -> Return) { withLock { fallback = body; sequence = nil } }

    public func setStub(when check: @escaping (Args) -> Bool, _ body: @escaping (Args) async -> Return) {
        withLock { conditional.append((check, body)) }
    }

    public func setSequence(_ values: [Return]) {
        withLock { sequence = values.isEmpty ? nil : values; sequenceIndex = 0; if !values.isEmpty { fallback = nil } }
    }

    public func record(_ args: Args, file: StaticString = #filePath, line: UInt = #line) async -> Return {
        let behavior: (Args) async -> Return = withLock {
            recordLocked(args)
            if let stub = conditional.first(where: { $0.check(args) }) { return stub.body }
            if let fallback { return fallback }
            if let sequence { let v = nextInSequence(sequence); return { _ in v } }
            if let fallbackDefault { return fallbackDefault }
            return { _ in SwiftMocks.unstubbed(self.member, file: file, line: line) }
        }
        return await behavior(args)
    }

    private func nextInSequence(_ values: [Return]) -> Return {
        let value = values[min(sequenceIndex, values.count - 1)]
        if sequenceIndex < values.count - 1 { sequenceIndex += 1 }
        return value
    }
}

// MARK: - async, throwing

public final class AsyncThrowingMock<Args, Return>: CallTracker<Args>, @unchecked Sendable {
    private var conditional: [(check: (Args) -> Bool, body: (Args) async throws -> Return)] = []
    private var fallback: ((Args) async throws -> Return)?
    private var sequence: [Return]?
    private var sequenceIndex = 0
    private let fallbackDefault: ((Args) -> Return)?
    private let member: String

    public init(_ member: String = "function") {
        self.fallbackDefault = nil
        self.member = member
    }

    public init(_ member: String = "function", default value: @escaping @autoclosure () -> Return) {
        self.fallbackDefault = { _ in value() }
        self.member = member
    }

    public func setStub(_ body: @escaping (Args) async throws -> Return) { withLock { fallback = body; sequence = nil } }

    public func setStub(when check: @escaping (Args) -> Bool, _ body: @escaping (Args) async throws -> Return) {
        withLock { conditional.append((check, body)) }
    }

    public func setError(_ error: Error) { withLock { fallback = { _ in throw error }; sequence = nil } }

    public func setSequence(_ values: [Return]) {
        withLock { sequence = values.isEmpty ? nil : values; sequenceIndex = 0; if !values.isEmpty { fallback = nil } }
    }

    public func record(_ args: Args, file: StaticString = #filePath, line: UInt = #line) async throws -> Return {
        let behavior: (Args) async throws -> Return = withLock {
            recordLocked(args)
            if let stub = conditional.first(where: { $0.check(args) }) { return stub.body }
            if let fallback { return fallback }
            if let sequence { let v = nextInSequence(sequence); return { _ in v } }
            if let fallbackDefault { return fallbackDefault }
            return { _ in SwiftMocks.unstubbed(self.member, file: file, line: line) }
        }
        return try await behavior(args)
    }

    private func nextInSequence(_ values: [Return]) -> Return {
        let value = values[min(sequenceIndex, values.count - 1)]
        if sequenceIndex < values.count - 1 { sequenceIndex += 1 }
        return value
    }
}
