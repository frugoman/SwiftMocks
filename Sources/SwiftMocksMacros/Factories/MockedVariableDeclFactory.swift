import SwiftSyntax

struct MockedVariableDeclFactory {
    func make(typeName: TokenSyntax, from classDecl: ClassDeclSyntax) -> VariableDeclSyntax {
        return VariableDeclSyntax(
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax(
                arrayLiteral:
                PatternBindingSyntax(
                    pattern: PatternSyntax(stringLiteral: "mock"),
                    initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: "\(typeName)()"))
                )
            )
        )
    }
}
