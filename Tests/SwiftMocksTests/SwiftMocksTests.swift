import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SwiftMocksMacros
import SwiftMocks

let testMacros: [String: Macro.Type] = [
    "Mock": SwiftMocksMacro.self,
]

final class MockTests: XCTestCase {
    func testMacro() {
        assertMacroExpansion(
            """
            @Mock
            class MyClass {
                func doAction(number: Int) -> String {}
            }
            """,
            expandedSource: """
            class MyClass {
                func doAction(number: Int) -> String {}
            
                let mock = MyClassMock()
            
                class MyClassMock {
                     var doActionCalls = Mock<(Int), String >()
                        func doAction(number: Int) -> String {
                        doActionCalls.record((number))
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroThrowable() {
        assertMacroExpansion(
            """
            @Mock
            class MyClass {
                func doAction() throws {}
            }
            """,
            expandedSource: """
            class MyClass {
                func doAction() throws {}
            
                let mock = MyClassMock()
            
                class MyClassMock {
                     var doActionCalls = MockThrowable<(Void), Void>()
                        func doAction() throws {
                        try doActionCalls.record(())
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroAsync() {
        assertMacroExpansion(
            """
            @Mock
            class MyClass {
                func doAction() async {}
            }
            """,
            expandedSource: """
            class MyClass {
                func doAction() async {}
            
                let mock = MyClassMock()
            
                class MyClassMock {
                     var doActionCalls = MockAsync<(Void), Void>()
                        func doAction() async {
                        await doActionCalls.record(())
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroAsyncThrowable() {
        assertMacroExpansion(
            """
            @Mock
            class MyClass {
                func doAction() async throws {}
            }
            """,
            expandedSource: """
            class MyClass {
                func doAction() async throws {}
            
                let mock = MyClassMock()
            
                class MyClassMock {
                     var doActionCalls = MockAsyncThrowable<(Void), Void>()
                        func doAction() async throws {
                        try await doActionCalls.record(())
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroWithVariables() {
        assertMacroExpansion(
            """
            @Mock
            class MyClass {
                var priority: Int { 0 }
            }
            """,
            expandedSource: """
            class MyClass {
                var priority: Int { 0 }
            
                let mock = MyClassMock()
            
                class MyClassMock {
                    var priority: MockVariable<Int > = .init()
                }
            }
            """,
            macros: testMacros
        )
    }
}
