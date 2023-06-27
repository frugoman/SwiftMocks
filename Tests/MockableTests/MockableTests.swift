import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacros
import Mockable

let testMacros: [String: Macro.Type] = [
    "Mock": MockableMacro.self,
]

final class MockableTests: XCTestCase {
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
                let mock = MyClassMockable()
                class MyClassMockable {
                     var doActionCalls: Mockable < (Void), Void> = .init()
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
                let mock = MyClassMockable()
                class MyClassMockable {
                    var priority: MockableVariable<Int > = .init()
                }
            }
            """,
            macros: testMacros
        )
    }
}
