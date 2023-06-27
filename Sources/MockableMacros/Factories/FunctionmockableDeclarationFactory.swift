import SwiftSyntax
import SwiftSyntaxBuilder

struct FunctionmockableDeclarationFactory {
    @MemberDeclListBuilder
    func callTrackerDeclarations(_ functions: [FunctionDeclSyntax]) -> MemberDeclListSyntax {
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
    }
    
    @MemberDeclListBuilder
    func mockImplementations(for functions: [FunctionDeclSyntax]) -> MemberDeclListSyntax {
        for function in functions {
            let paramsValues = function.signature.input.parameterList
                .map {
                    $0.secondName?.text != nil ? $0.secondName!.text : $0.firstName.text
                }
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
}
