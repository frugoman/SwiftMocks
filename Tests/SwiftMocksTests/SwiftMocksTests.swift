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
    let expectedSource = """
        class MyClass {
            func doAction() {
            }
            let mock = MyClassMock()
            class MyClassMock {
                var doActionCalls: Mock<(Void), Void> = .init()
                func doAction() {
                    doActionCalls.record(())
                }
            }
        }
        """
        let inputSource = """
        @Mock
        class MyClass {
            func doAction() {}
        }
        """
        let actualSource = expandMacro(inputSource, macros: testMacros)
        XCTAssertEqual(actualSource, expectedSource)
    }
    
    func testMacroWithVariables() {
        let expectedSource = """
        class MyClass {
            var priority: Int {
                0
            }
            let mock = MyClassMock()
            class MyClassMock {
                var priority: MockVariable<Int> = .init()
            }
        }
        """
        let inputSource = """
        @Mock
        class MyClass {
            var priority: Int { 0 }
        }
        """
        let actualSource = expandMacro(inputSource, macros: testMacros)
        XCTAssertEqual(actualSource, expectedSource)
    }
}
