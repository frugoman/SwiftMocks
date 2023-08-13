import SwiftSyntax
import SwiftSyntaxBuilder

struct FunctionMockableDeclarationFactory {
    @MemberBlockItemListBuilder
    func callTrackerDeclarations(_ functions: [FunctionDeclSyntax]) -> MemberBlockItemListSyntax {
        for function in functions {
            let params = function.signature.parameterClause.parameters
                .map { $0.type }
                .map { type in
                    GenericParameterSyntax.init(name: TokenSyntax(stringLiteral: type.description))
                }
            let returnType = function.signature.returnClause?.type.description ?? "Void"
            
            let voidOne = GenericParameterSyntax.init(name: TokenSyntax(stringLiteral: "Void"))
            
            let pa = GenericParameterListSyntax(params.count == 0 ? [voidOne] : params).map { p in
                p.description
            }.joined(separator: ", ")
            VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([.init(name: .identifier(""))]),
                .var,
                name: PatternSyntax(stringLiteral: function.name.text + "Calls = Mock<(\(pa)), \(returnType)>()")
            )
        }
    }
    
    @MemberBlockItemListBuilder
    func mockImplementations(for functions: [FunctionDeclSyntax]) -> MemberBlockItemListSyntax {
        for function in functions {
            let paramsValues = function.signature.parameterClause.parameters
                .map {
                    $0.secondName?.text != nil ? $0.secondName!.text : $0.firstName.text
                }
            FunctionDeclSyntax(
                attributes: function.attributes,
                modifiers: function.modifiers,
                funcKeyword: function.funcKeyword,
                identifier: function.name,
                genericParameterClause: function.genericParameterClause,
                signature: function.signature,
                genericWhereClause: function.genericWhereClause) {
                    CodeBlockItemSyntax(stringLiteral: function.name.text + "Calls." + "record((\(paramsValues.joined(separator: ", "))))")
                }
        }
    }
}
