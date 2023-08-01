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
                func doAction() {}
            }
            """,
            expandedSource: """
            class MyClass {
                func doAction() {
                }
                let mock = MyClassMock()
                class MyClassMock {
                     var doActionCalls = Mock < (Void), Void>()
                        func doAction() {
                        doActionCalls.record(())
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
                var priority: Int {
                    0
                }
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
