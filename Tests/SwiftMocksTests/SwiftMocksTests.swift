import XCTest
import Testing
import SwiftMocks
import SwiftMocksXCTest
import SwiftMocksTesting
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

// MARK: - Class target

@Mock
class Repository {
    func load(id: Int) -> String { "real-\(id)" }
    func save() throws {}
    var count: Int { -1 }
}

final class ClassTargetTests: XCTestCase {
    func testOverridesMethodAndRecords() {
        let repo = RepositoryMock()
        repo.stub.load { id in "mock-\(id)" }

        XCTAssertEqual(repo.load(id: 1), "mock-1")   // overridden, not the real "real-1"
        XCTAssertTrue(repo.verify.load.calledWith(1))
    }

    func testOverridesComputedProperty() {
        let repo = RepositoryMock()
        repo.stub.count(returns: 7)
        XCTAssertEqual(repo.count, 7)                // overridden, not the real -1
        XCTAssertTrue(repo.verify.count.calledOnce)
    }

    func testThrowingVoidMethodIsSpyable() throws {
        let repo = RepositoryMock()
        try repo.save()                              // Void: no stub needed
        XCTAssertTrue(repo.verify.save.calledOnce)
    }

    func testUsableThroughBaseClass() {
        let repo: Repository = RepositoryMock()      // is-a Repository
        (repo as? RepositoryMock)?.stub.load { _ in "x" }
        XCTAssertEqual(repo.load(id: 9), "x")
    }
}

// MARK: - Overloaded members

@Mock
protocol Sender {
    func send(_ value: Int) -> String
    func send(_ value: String) -> String
    func move(x: Int)
    func move(y: Int)
}

final class OverloadTests: XCTestCase {
    func testTypeDistinguishedOverloads() {
        let sender = SenderMock()
        sender.stub.send_Int(returns: "int")
        sender.stub.send_String(returns: "str")

        XCTAssertEqual(sender.send(1), "int")
        XCTAssertEqual(sender.send("a"), "str")
        XCTAssertTrue(sender.verify.send_Int.calledOnce)
        XCTAssertTrue(sender.verify.send_String.calledOnce)
    }

    func testLabelDistinguishedOverloads() {
        let sender = SenderMock()
        sender.move(x: 1)
        XCTAssertTrue(sender.verify.move_x.calledWith(1))
        XCTAssertTrue(sender.verify.move_y.neverCalled)
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

// MARK: - Failure-reporter adapters

#if canImport(Darwin)   // XCTExpectFailure is Apple-only; not in swift-corelibs-xctest
final class XCTestAdapterTests: XCTestCase {
    func testRoutesFailureToXCTFail() {
        let original = SwiftMocks.failureReporter
        defer { SwiftMocks.failureReporter = original }

        SwiftMocks.useXCTest()
        XCTExpectFailure("a SwiftMocks failure should surface as an XCTest failure")
        SwiftMocks.failureReporter("boom", #filePath, #line)
    }
}
#endif

@Test func swiftTestingAdapterRecordsIssue() {
    let original = SwiftMocks.failureReporter
    defer { SwiftMocks.failureReporter = original }

    SwiftMocks.useSwiftTesting()
    withKnownIssue("a SwiftMocks failure should surface as a recorded issue") {
        SwiftMocks.failureReporter("boom", #filePath, #line)
    }
}

// MARK: - Diagnostics

let testMacros: [String: Macro.Type] = ["Mock": SwiftMocksMacro.self]

final class MockDiagnosticsTests: XCTestCase {
    func testFinalClassMemberIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            class Service {
                final func locked() {}
            }
            """,
            expandedSource: """
            class Service {
                final func locked() {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' can't mock a 'final' member of a class; remove 'final' or extract a protocol", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testStoredPropertyIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            class Service {
                var count: Int = 0
            }
            """,
            expandedSource: """
            class Service {
                var count: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' can't mock a stored property of a class; make it computed or extract a protocol", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testMultipleInheritanceIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Combined: Base, Other {
                func foo()
            }
            """,
            expandedSource: """
            protocol Combined: Base, Other {
                func foo()
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' supports inheriting from at most one other protocol (which must itself be '@Mock'); flatten the rest into the mocked protocol", line: 1, column: 1)
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

    func testVariadicParameterIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Printer {
                func print(_ items: Int...)
            }
            """,
            expandedSource: """
            protocol Printer {
                func print(_ items: Int...)
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' does not yet support variadic parameters", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testInoutParameterIsDiagnosed() {
        assertMacroExpansion(
            """
            @Mock
            protocol Mutator {
                func mutate(_ value: inout Int)
            }
            """,
            expandedSource: """
            protocol Mutator {
                func mutate(_ value: inout Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Mock' does not yet support 'inout' parameters", line: 1, column: 1)
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

// Protocol inheritance: DogMock subclasses AnimalMock, inheriting its members, trackers,
// and stub/verify facades.
@Mock
protocol Animal {
    func sound() -> String
    var legs: Int { get }
}

@Mock
protocol Dog: Animal {
    func fetch() -> String
}

final class ProtocolInheritanceTests: XCTestCase {
    func testInheritedAndOwnMembersBothWork() {
        let dog = DogMock()
        dog.stub.sound(returns: "woof")   // inherited member, stubbed via inherited facade
        dog.stub.legs(returns: 4)         // inherited property
        dog.stub.fetch(returns: "stick")  // own member

        XCTAssertEqual(dog.sound(), "woof")
        XCTAssertEqual(dog.legs, 4)
        XCTAssertEqual(dog.fetch(), "stick")

        XCTAssertTrue(dog.verify.sound.calledOnce)   // verify inherited member
        XCTAssertTrue(dog.verify.fetch.calledOnce)   // verify own member
    }

    func testUsableThroughBaseProtocol() {
        let dog = DogMock()
        dog.stub.sound(returns: "bark")
        let animal: Animal = dog          // satisfies the base protocol
        XCTAssertEqual(animal.sound(), "bark")
        XCTAssertTrue(dog.verify.sound.calledWith(.any))
    }
}
