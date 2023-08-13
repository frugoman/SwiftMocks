import SwiftSyntax
import SwiftSyntaxBuilder

struct MockVariableDeclarationFactory {
    @MemberBlockItemListBuilder
    func mockVariableDeclarations(_ variables: [VariableDeclSyntax]) -> MemberBlockItemListSyntax {
        for variable in variables {
            mockVariableDeclaration(variable)
        }
    }
    
    @MemberBlockItemListBuilder
    func mockVariableDeclaration(_ variable: VariableDeclSyntax) -> MemberBlockItemListSyntax {
        if let binding = variable.bindings.first, let type = binding.typeAnnotation?.type.description {
            VariableDeclSyntax(
                bindingSpecifier: .keyword(.var),
                bindings: .init(
                    arrayLiteral: PatternBindingSyntax(
                        pattern: binding.pattern,
                        typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "MockVariable<\(type)>")),
                        initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: ".init()")))
                )
            )
        }
    }
}
