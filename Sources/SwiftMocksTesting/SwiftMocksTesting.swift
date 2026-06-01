import Testing
import SwiftMocks

public extension SwiftMocks {
    /// Routes in-mock failures (such as calling an un-stubbed returning member) to
    /// swift-testing's `Issue.record`, so they appear as recorded issues. Call once before
    /// your mocks run — e.g. in a suite `init` or a shared helper.
    static func useSwiftTesting() {
        failureReporter = { message, _, _ in
            Issue.record(Comment(rawValue: message))
        }
    }
}
