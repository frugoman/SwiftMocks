import SwiftSyntax
import SwiftSyntaxMacros

public struct SwiftMocksMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else { return [] }
        let stackIdentifier = TokenSyntax.identifier(classDecl.identifier.text + "Mock")
        
        return [
            DeclSyntax(MockedVariableDeclFactory().make(typeName: stackIdentifier, from: classDecl)),
            DeclSyntax(MockedClassDeclFactory().make(typeName: stackIdentifier, from: classDecl))
        ]
    }
}
