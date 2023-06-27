import SwiftSyntax

struct MockedClassDeclFactory {
    func make(typeName: TokenSyntax, from classDecl: ClassDeclSyntax) -> ClassDeclSyntax {
        ClassDeclSyntax(
            identifier: typeName,
            memberBlockBuilder: {
                let variables = classDecl.memberBlock.members
                    .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                MockVariableDeclarationFactory().mockVariableDeclarations(variables)
                
                let functions = classDecl.memberBlock.members
                    .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
                
                let functionsFactory = FunctionmockableDeclarationFactory()
                functionsFactory.callTrackerDeclarations(functions)
                functionsFactory.mockImplementations(for: functions)
            }
        )
    }
}
