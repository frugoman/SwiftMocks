import SwiftSyntax
import SwiftSyntaxBuilder

struct FunctionMockableDeclarationFactory {
    @MemberBlockItemListBuilder
    func callTrackerDeclarations(_ functions: [FunctionDeclSyntax]) -> MemberBlockItemListSyntax {
        for function in functions {
            let params = function.signature
                .parameterClause
                .parameters
                .map { $0.type }
                .map { type in
                    GenericParameterSyntax(name: TokenSyntax(stringLiteral: type.description))
                }
            let returnType = function.signature.returnClause?.type.description ?? "Void"
            
            let voidOne = GenericParameterSyntax.init(name: TokenSyntax(stringLiteral: "Void"))
            
            let parameterValues = GenericParameterListSyntax(params.count == 0 ? [voidOne] : params).map { p in
                p.description
            }
            
            let mockName = getMock(function)
            
            VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([.init(name: .identifier(""))]),
                .var,
                name: PatternSyntax(stringLiteral: function.name.text + "Calls = \(mockName)<(\(parameterValues.joined(separator: ", "))), \(returnType)>()")
            )
        }
    }
    
    @MemberBlockItemListBuilder
    func mockImplementations(for functions: [FunctionDeclSyntax]) -> MemberBlockItemListSyntax {
        for function in functions {
            let parameterValues = function.signature
                .parameterClause
                .parameters
                .map {
                    $0.secondName?.text != nil ? $0.secondName!.text : $0.firstName.text
                }
            
            FunctionDeclSyntax(
                attributes: function.attributes,
                modifiers: function.modifiers,
                funcKeyword: function.funcKeyword,
                name: function.name,
                genericParameterClause: function.genericParameterClause,
                signature: function.signature,
                genericWhereClause: function.genericWhereClause) {
                    CodeBlockItemSyntax(stringLiteral: getMockCallFunctionDeclaration(function) + "Calls." + "record((\(parameterValues.joined(separator: ", "))))")
                }
        }
    }
    
    private func getMock(_ function: FunctionDeclSyntax) -> String {
        let isAsync = isAsyncFuction(function)
        let isThrowing = isThrowingFuction(function)
        
        if isAsync && isThrowing {
            return "MockAsyncThrowable"
        } else if isThrowing {
            return "MockThrowable"
        } else if isAsync {
            return "MockAsync"
        } else {
            return "Mock"
        }
    }
    
    private func isThrowingFuction(_ function: FunctionDeclSyntax) -> Bool {
        function.signature.effectSpecifiers?.throwsSpecifier?.text == "throws"
    }
    
    private func isAsyncFuction(_ function: FunctionDeclSyntax) -> Bool {
        function.signature.effectSpecifiers?.asyncSpecifier?.text == "async"
    }
    
    private func getMockCallFunctionDeclaration(_ function: FunctionDeclSyntax) -> String {
        var callMockImplementation: [String] = []
        
        if isThrowingFuction(function) {
            callMockImplementation.append("try")
        }
        
        if isAsyncFuction(function) {
            callMockImplementation.append("await")
        }
        
        callMockImplementation.append(function.name.text)
        
        return callMockImplementation.joined(separator: " ")
    }
}
