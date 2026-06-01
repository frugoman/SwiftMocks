/// Framework-agnostic sink for failures that originate *inside* a Mock Type mid-call —
/// for example, calling a member with a non-trivial return type that was never stubbed.
///
/// The core library has no dependency on XCTest or swift-testing. Thin adapter modules
/// (`SwiftMocksXCTest`, `SwiftMocksTesting`) install a reporter that routes to `XCTFail`
/// or `Issue.record` respectively. Verify Surface assertions do *not* go through here —
/// they return `Bool` and are checked by the test's own `#expect`/`XCTAssert`.
public enum SwiftMocks {
    /// The active failure handler. Defaults to a trap so an unconfigured mock fails loudly
    /// rather than silently passing a call through. Adapter modules replace this.
    ///
    /// Marked `nonisolated(unsafe)`: mocks are test-only and effectively single-threaded
    /// per test; this avoids forcing every consumer into actor isolation.
    public nonisolated(unsafe) static var failureReporter: (String, StaticString, UInt) -> Void = { message, file, line in
        fatalError(message, file: file, line: line)
    }

    /// Reports a recoverable failure (e.g. a Verify-adjacent check) and returns control.
    static func reportFailure(_ message: String, file: StaticString, line: UInt) {
        failureReporter(message, file, line)
    }

    /// Reports the failure, then traps — used on the unstubbed-call path for a member whose
    /// return type cannot be trivially defaulted, where there is genuinely no value to return.
    /// The reporter fires first so the test framework records a readable failure; the trap is
    /// the unavoidable consequence of having no value to produce.
    static func unstubbed<T>(_ member: String, file: StaticString, line: UInt) -> T {
        reportFailure("SwiftMocks: '\(member)' was called but no stub or default was configured", file: file, line: line)
        fatalError("SwiftMocks: '\(member)' was called but no stub or default was configured", file: file, line: line)
    }
}
