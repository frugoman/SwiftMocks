import XCTest
import SwiftMocks

public extension SwiftMocks {
    /// Routes in-mock failures (such as calling an un-stubbed returning member) to XCTest's
    /// `XCTFail`, so they appear as ordinary test failures. Call once before your mocks run —
    /// e.g. in a test case's `setUp()`.
    static func useXCTest() {
        failureReporter = { message, file, line in
            XCTFail(message, file: file, line: line)
        }
    }
}
