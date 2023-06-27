import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SwiftMocksMacros
import SwiftMocks

let testMacros: [String: Macro.Type] = [
    "Mock": SwiftMocksMacro.self,
]

final class SwiftMocksTests: XCTestCase {
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
                let mock = MyClassSwiftMocks()
                class MyClassSwiftMocks {
                     var doActionCalls: SwiftMocks < (Void), Void> = .init()
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
                let mock = MyClassSwiftMocks()
                class MyClassSwiftMocks {
                    var priority: SwiftMocksVariable<Int > = .init()
                }
            }
            """,
            macros: testMacros
        )
    }
}
