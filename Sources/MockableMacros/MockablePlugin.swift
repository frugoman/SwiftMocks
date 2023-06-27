import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MockablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self
    ]
}
