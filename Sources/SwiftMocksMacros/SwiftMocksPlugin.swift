import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftMocksPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SwiftMocksMacro.self
    ]
}
