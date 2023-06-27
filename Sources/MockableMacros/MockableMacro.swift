import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
                        typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "MockableVariable<\(type)>")),
                        initializer: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: ".init()"))
                    )
                }
            )
        }
    }
}

public struct MockableMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { return [] }
        let stackIdentifier = TokenSyntax.identifier(classDecl.identifier.text + "Mockable")
        return [
            "let mock = \(stackIdentifier)()",
            DeclSyntax(
                ClassDeclSyntax(
                    identifier: stackIdentifier,
                    memberBlockBuilder: {
                        let variables = classDecl.memberBlock.members
                            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                        
                        let functions = classDecl.memberBlock.members
                            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
                        
                        MockVariableDeclarationFactory().mockVariableDeclarations(variables)
                        
                        for function in functions {
                            let params = function.signature.input.parameterList
                                .map { $0.type }
                                .map { type in
                                    GenericParameterSyntax.init(name: TokenSyntax(stringLiteral: type.description))
                                }
                            let returnType = function.signature.output?.returnType.description ?? "Void"
                            
                            let voidOne = GenericParameterSyntax.init(name: TokenSyntax(stringLiteral: "Void"))
                            
                            let pa = GenericParameterListSyntax(params.count == 0 ? [voidOne] : params).map { p in
                                p.description
                            }.joined(separator: ", ")
                            VariableDeclSyntax(
                                modifiers: ModifierListSyntax([.init(name: .identifier(""))]),
                                .var,
                                name: PatternSyntax(stringLiteral: function.identifier.text + "Calls: Mockable<(\(pa)), \(returnType)> = .init()")
                            )
                        }
                        
                        for function in functions {
                            let paramsValues = function.signature.input.parameterList
                                .map { $0.firstName.text }
                            FunctionDeclSyntax(
                                attributes: function.attributes,
                                modifiers: function.modifiers,
                                funcKeyword: function.funcKeyword,
                                identifier: function.identifier,
                                genericParameterClause: function.genericParameterClause,
                                signature: function.signature,
                                genericWhereClause: function.genericWhereClause) {
                                    CodeBlockItemSyntax(stringLiteral: function.identifier.text + "Calls." + "record((\(paramsValues.joined(separator: ", "))))")
                                }
                        }
                    }
                )
            )]
    }
}
