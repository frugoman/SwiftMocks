import XCTest
import SwiftMocks
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftMocksMacros

// MARK: - Subjects under test

@Mock
protocol Calculator {
    var total: Int { get set }
    var label: String { get }
    func add(_ a: Int, _ b: Int) -> Int
    func reset()
    func maybe() -> Int?
    func risky() throws -> Int
    func fetch() async -> String
    func load(id: Int) async throws -> String
}

enum TestError: Error { case boom }

// MARK: - Behavioural tests

final class MockBehaviourTests: XCTestCase {
    func testRecordsCallsAndVerifies() {
        let mock = CalculatorMock()
        mock.stub.add { a, b in a + b }

        XCTAssertEqual(mock.add(2, 3), 5)
        XCTAssertTrue(mock.verify.add.calledOnce)
        XCTAssertEqual(mock.verify.add.callsCount, 1)
        XCTAssertTrue(mock.verify.reset.neverCalled)
    }

    func testStubReturns() {
        let mock = CalculatorMock()
        mock.stub.add(returns: 99)
        XCTAssertEqual(mock.add(1, 1), 99)
    }

    func testCalledWithValueAndMatcher() {
        let mock = CalculatorMock()
        mock.stub.add { _, _ in 0 }
        _ = mock.add(2, 3)

        XCTAssertTrue(mock.verify.add.calledWith(.where { $0.0 == 2 && $0.1 == 3 }))
        XCTAssertTrue(mock.verify.add.calledWith(.any))
        XCTAssertFalse(mock.verify.add.calledWith(.where { $0.0 == 9 }))
    }

    func testTriviallyDefaultedReturnsNeedNoStub() {
        let mock = CalculatorMock()
        mock.reset()                          // Void return: records, no stub needed
        XCTAssertEqual(mock.maybe(), nil)     // Optional return: defaults to nil
        XCTAssertTrue(mock.verify.reset.calledOnce)
        XCTAssertEqual(mock.verify.maybe.callsCount, 1)
    }

    func testThrowingErrorStub() {
        let mock = CalculatorMock()
        mock.stub.risky(throws: TestError.boom)
        XCTAssertThrowsError(try mock.risky()) { error in
            XCTAssertEqual(error as? TestError, .boom)
        }
        XCTAssertTrue(mock.verify.risky.calledOnce)
    }

    func testThrowingValueStub() throws {
        let mock = CalculatorMock()
        mock.stub.risky(returns: 7)
        XCTAssertEqual(try mock.risky(), 7)
    }

    func testAsync() async {
        let mock = CalculatorMock()
        mock.stub.fetch(returns: "hi")
        let value = await mock.fetch()
        XCTAssertEqual(value, "hi")
        XCTAssertTrue(mock.verify.fetch.calledOnce)
    }

    func testAsyncThrows() async throws {
        let mock = CalculatorMock()
        mock.stub.load { id in "loaded-\(id)" }
        let value = try await mock.load(id: 3)
        XCTAssertEqual(value, "loaded-3")
        XCTAssertTrue(mock.verify.load.calledWith(.where { $0 == 3 }))
    }

    func testSequence() {
        let mock = CalculatorMock()
        mock.stub.add(inSequence: [10, 20, 30])
        XCTAssertEqual(mock.add(0, 0), 10)
        XCTAssertEqual(mock.add(0, 0), 20)
        XCTAssertEqual(mock.add(0, 0), 30)
        XCTAssertEqual(mock.add(0, 0), 30)   // exhausted: repeats last
    }

    func testConditionalStub() {
        let mock = CalculatorMock()
        mock.stub.add { _, _ in -1 }                       // fallback
        mock.stub.add(when: .eq(1), .eq(1)) { _, _ in 2 }  // conditional

        XCTAssertEqual(mock.add(1, 1), 2)   // conditional wins
        XCTAssertEqual(mock.add(5, 5), -1)  // falls back
    }

    func testSettableProperty() {
        let mock = CalculatorMock()
        mock.stub.total(returns: 0)
        mock.total = 42
        _ = mock.total

        XCTAssertTrue(mock.verify.totalSet.calledWith(42))
        XCTAssertTrue(mock.verify.total.calledOnce)
    }

    func testGetOnlyProperty() {
        let mock = CalculatorMock()
        mock.stub.label(returns: "name")
        XCTAssertEqual(mock.label, "name")
    }
}

// MARK: - README snippets (kept compiling so docs can't drift)

@Mock
protocol ReadmeAPI {
    func perform(with value: Int) -> String
    func send(id: Int, tag: String)
}

final class ReadmeSnippetTests: XCTestCase {
    func testSingleArgCalledWithValue() {
        let api = ReadmeAPIMock()
        api.stub.perform { value in "got \(value)" }
        XCTAssertEqual(api.perform(with: 7), "got 7")
        XCTAssertTrue(api.verify.perform.calledWith(7))            // plain Equatable value
        XCTAssertTrue(api.verify.perform.calledWith(.where { $0 > 0 }))
    }

    func testMultiArgVoidTupleMatcher() {
        let api = ReadmeAPIMock()
        api.send(id: 1, tag: "x")                                 // Void: no stub needed
        XCTAssertTrue(api.verify.send.calledWith(.where { $0.0 == 1 && $0.1 == "x" }))
    }
}

// MARK: - Diagnostics

let testMacros: [String: Macro.Type] = ["Mock": SwiftMocksMacro.self]

final class MockDiagnosticsTests: XCTestCase {
    func testClassTargetIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            class Foo {
            }
            """,
            expandedSource: """
            class Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' on classes is not yet supported; attach it to a protocol", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testInheritedRequirementsAreDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Derived: Base {
                func foo()
            }
            """,
            expandedSource: """
            protocol Derived: Base {
                func foo()
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' does not yet support inherited protocol requirements (from 'Base'); flatten the requirements into the mocked protocol", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testStaticRequirementIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Factory {
                static func make()
            }
            """,
            expandedSource: """
            protocol Factory {
                static func make()
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' does not yet support static requirements", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testSubscriptRequirementIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Container {
                subscript(index: Int) -> String { get }
            }
            """,
            expandedSource: """
            protocol Container {
                subscript(index: Int) -> String { get }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' does not yet support subscript requirements", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

}

// A marker protocol carries no requirements, so `: Sendable` must NOT be diagnosed and the
// mock should generate and work normally.
@Mock
protocol Worker: Sendable {
    func work()
}

final class SendableInheritanceTests: XCTestCase {
    func testMarkerInheritanceIsAllowed() {
        let worker = WorkerMock()
        worker.work()
        XCTAssertTrue(worker.verify.work.calledOnce)
    }
}
