import SwiftSyntax

struct MockedVariableDeclFactory {
    func make(typeName: TokenSyntax, from classDecl: ClassDeclSyntax) -> VariableDeclSyntax {
        VariableDeclSyntax(
            bindingKeyword: .keyword(.let),
            bindingsBuilder: {
                PatternBindingSyntax(
                    pattern: PatternSyntax(stringLiteral: "mock"),
                    initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: "\(typeName)()"))
                )
            }
        )
    }
}
