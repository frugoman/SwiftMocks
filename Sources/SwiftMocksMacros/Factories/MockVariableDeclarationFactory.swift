import SwiftSyntax
import SwiftSyntaxBuilder

struct MockVariableDeclarationFactory {
    @MemberDeclListBuilder
    func mockVariableDeclarations(_ variables: [VariableDeclSyntax]) -> MemberDeclListSyntax {
        for variable in variables {
            mockVariableDeclaration(variable)
        }
    }
    
    @MemberDeclListBuilder
    func mockVariableDeclaration(_ variable: VariableDeclSyntax) -> MemberDeclListSyntax {
        if let binding = variable.bindings.first, let type = binding.typeAnnotation?.type.description {
            VariableDeclSyntax(
                bindingKeyword: .keyword(.var),
                bindingsBuilder: {
                    PatternBindingSyntax(
                        pattern: binding.pattern,
                        typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "MockVariable<\(type)>")),
                        initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: ".init()"))
                    )
                }
            )
        }
    }
}
