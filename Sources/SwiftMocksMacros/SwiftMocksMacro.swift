import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// `@Mock` is a peer macro: attached to a protocol (primary) or class (secondary), it emits
// a sibling Mock Type — e.g. `ServiceMock` for `Service` — that implements every member by
// forwarding into a CallTracker, and exposes `.stub` / `.verify` surfaces.
//
// This first cut fully supports PROTOCOL targets (functions across all four effect
// signatures, plus get / get-set properties). Class targets, overloaded members, and a few
// edge cases emit diagnostics rather than generating incorrect code.
public struct SwiftMocksMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            if declaration.is(ClassDeclSyntax.self) {
                context.diagnose(Diagnostic(node: node, message: MockDiagnostic.classTargetUnsupported))
            } else {
                context.diagnose(Diagnostic(node: node, message: MockDiagnostic.notProtocolOrClass))
            }
            return []
        }

        let members = proto.memberBlock.members
        let functions = members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
        let properties = members.compactMap { $0.decl.as(VariableDeclSyntax.self) }

        // Overloaded members would collide on tracker names and the `verify`/`stub` facades.
        let duplicateNames = Dictionary(grouping: functions, by: { $0.name.text })
            .filter { $1.count > 1 }.keys
        if let name = duplicateNames.sorted().first {
            context.diagnose(Diagnostic(node: node, message: MockDiagnostic.overloadUnsupported(name)))
            return []
        }

        let funcModels = functions.map(FunctionModel.init)
        let propModels = properties.compactMap { PropertyModel($0) }

        let mockName = proto.name.text + "Mock"
        let source = render(mockName: mockName, conformsTo: proto.name.text, functions: funcModels, properties: propModels)
        return [DeclSyntax(stringLiteral: source)]
    }
}

// MARK: - Member models

private struct FunctionModel {
    let name: String
    let paramTypes: [String]
    let argNames: [String]          // internal parameter names, for forwarding
    let signature: String           // "(id: Int) async throws -> Data"
    let generics: String
    let whereClause: String
    let isAsync: Bool
    let isThrows: Bool
    let returnType: String          // "Void" when no explicit return

    init(_ f: FunctionDeclSyntax) {
        name = f.name.text
        let params = f.signature.parameterClause.parameters
        paramTypes = params.map { $0.type.trimmedDescription }
        argNames = params.map { ($0.secondName ?? $0.firstName).text }
        signature = f.signature.trimmedDescription
        generics = f.genericParameterClause?.trimmedDescription ?? ""
        whereClause = f.genericWhereClause.map { " " + $0.trimmedDescription } ?? ""
        let effects = f.signature.effectSpecifiers
        isAsync = effects?.asyncSpecifier != nil
        isThrows = effects?.throwsClause != nil
        returnType = f.signature.returnClause?.type.trimmedDescription ?? "Void"
    }
}

private struct PropertyModel {
    let name: String
    let type: String
    let isSettable: Bool

    init?(_ v: VariableDeclSyntax) {
        guard let binding = v.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type.trimmedDescription else { return nil }
        name = identifier
        self.type = type
        // A protocol property is settable when its accessor block declares `set`.
        if case .accessors(let list)? = binding.accessorBlock?.accessors {
            isSettable = list.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
        } else {
            isSettable = false
        }
    }
}

// MARK: - Rendering

private func render(mockName: String, conformsTo: String, functions: [FunctionModel], properties: [PropertyModel]) -> String {
    var trackers: [String] = []
    var conformance: [String] = []
    var stub: [String] = []
    var verify: [String] = []

    for f in functions {
        let tracker = "_mock_\(f.name)"
        let trackerType = effectTrackerType(isAsync: f.isAsync, isThrows: f.isThrows)
        let argsType = f.paramTypes.isEmpty ? "Void" : "(" + f.paramTypes.joined(separator: ", ") + ")"
        let initArgs = defaultLiteral(for: f.returnType).map { "\"\(f.name)\", default: \($0)" } ?? "\"\(f.name)\""
        trackers.append("let \(tracker) = \(trackerType)<\(argsType), \(f.returnType)>(\(initArgs))")

        let tryAwait = (f.isThrows ? "try " : "") + (f.isAsync ? "await " : "")
        let forwardArgs = f.argNames.joined(separator: ", ")
        conformance.append("""
        func \(f.name)\(f.generics)\(f.signature)\(f.whereClause) {
            \(tryAwait)\(tracker).record((\(forwardArgs)))
        }
        """)

        stub.append(contentsOf: stubMethods(f, tracker: tracker))
        verify.append("var \(f.name): \(trackerType)<\(argsType), \(f.returnType)> { target.\(tracker) }")
    }

    for p in properties {
        let getTracker = "_mock_\(p.name)_get"
        trackers.append("let \(getTracker) = Mock<Void, \(p.type)>(\(defaultLiteral(for: p.type).map { "\"\(p.name)\", default: \($0)" } ?? "\"\(p.name)\""))")
        if p.isSettable {
            let setTracker = "_mock_\(p.name)_set"
            trackers.append("let \(setTracker) = Mock<\(p.type), Void>(\"\(p.name)\", default: ())")
            conformance.append("""
            var \(p.name): \(p.type) {
                get { \(getTracker).record(()) }
                set { \(setTracker).record((newValue)) }
            }
            """)
            verify.append("var \(p.name)Set: Mock<\(p.type), Void> { target.\(setTracker) }")
        } else {
            conformance.append("var \(p.name): \(p.type) { \(getTracker).record(()) }")
        }
        stub.append("func \(p.name)(_ body: @escaping () -> \(p.type)) { target.\(getTracker).setStub { _ in body() } }")
        stub.append("func \(p.name)(returns value: \(p.type)) { target.\(getTracker).setStub { _ in value } }")
        verify.append("var \(p.name): Mock<Void, \(p.type)> { target.\(getTracker) }")
    }

    func indent(_ lines: [String], _ spaces: Int) -> String {
        let pad = String(repeating: " ", count: spaces)
        return lines.joined(separator: "\n").split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : pad + $0 }.joined(separator: "\n")
    }

    return """
    final class \(mockName): \(conformsTo), @unchecked Sendable {
    \(indent(trackers, 4))

        init() {}

    \(indent(conformance, 4))

        var stub: Stub { Stub(self) }
        var verify: Verify { Verify(self) }

        struct Stub {
            let target: \(mockName)
            init(_ target: \(mockName)) { self.target = target }
    \(indent(stub, 8))
        }

        struct Verify {
            let target: \(mockName)
            init(_ target: \(mockName)) { self.target = target }
    \(indent(verify, 8))
        }
    }
    """
}

private func stubMethods(_ f: FunctionModel, tracker: String) -> [String] {
    let tryAwait = (f.isThrows ? "try " : "") + (f.isAsync ? "await " : "")
    let effects = (f.isAsync ? "async " : "") + (f.isThrows ? "throws " : "")
    let closureType = "(\(f.paramTypes.joined(separator: ", "))) \(effects)-> \(f.returnType)"

    // Bridge the user's natural multi-arg closure to the tracker's tuple closure.
    let forwardCall: String
    switch f.argNames.count {
    case 0: forwardCall = "\(tryAwait)body()"
    case 1: forwardCall = "\(tryAwait)body(a)"
    default:
        let parts = (0..<f.argNames.count).map { "a.\($0)" }.joined(separator: ", ")
        forwardCall = "\(tryAwait)body(\(parts))"
    }

    var methods: [String] = []
    methods.append("func \(f.name)(_ body: @escaping \(closureType)) { target.\(tracker).setStub { a in \(forwardCall) } }")

    if f.returnType != "Void" {
        methods.append("func \(f.name)(returns value: \(f.returnType)) { target.\(tracker).setStub { _ in value } }")
        methods.append("func \(f.name)(inSequence values: [\(f.returnType)]) { target.\(tracker).setSequence(values) }")
    }
    if f.isThrows {
        methods.append("func \(f.name)(throws error: Error) { target.\(tracker).setError(error) }")
    }
    if !f.paramTypes.isEmpty {
        let matcherParams = f.paramTypes.enumerated()
            .map { i, t in "\(i == 0 ? "when" : "_") m\(i): ArgumentMatcher<\(t)>" }
            .joined(separator: ", ")
        let matchExpr: String
        if f.paramTypes.count == 1 {
            matchExpr = "m0.matches(a)"
        } else {
            matchExpr = (0..<f.paramTypes.count).map { "m\($0).matches(a.\($0))" }.joined(separator: " && ")
        }
        methods.append("func \(f.name)(\(matcherParams), _ body: @escaping \(closureType)) { target.\(tracker).setStub(when: { a in \(matchExpr) }, { a in \(forwardCall) }) }")
    }
    return methods
}

private func effectTrackerType(isAsync: Bool, isThrows: Bool) -> String {
    switch (isAsync, isThrows) {
    case (false, false): return "Mock"
    case (false, true): return "ThrowingMock"
    case (true, false): return "AsyncMock"
    case (true, true): return "AsyncThrowingMock"
    }
}

/// The literal used to satisfy a Trivially-Defaulted Return, or nil if the type must be stubbed.
private func defaultLiteral(for type: String) -> String? {
    let t = type
    if t == "Void" || t == "()" { return "()" }
    if t.hasSuffix("?") || t.hasPrefix("Optional<") { return "nil" }
    if t.hasPrefix("[") && t.contains(":" as Character) { return "[:]" }
    if t.hasPrefix("[") { return "[]" }
    if t.hasPrefix("Array<") || t.hasPrefix("Set<") { return "[]" }
    if t.hasPrefix("Dictionary<") { return "[:]" }
    return nil
}

// MARK: - Diagnostics

private struct MockDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ message: String, _ id: String, _ severity: DiagnosticSeverity = .error) {
        self.message = message
        self.diagnosticID = MessageID(domain: "SwiftMocks", id: id)
        self.severity = severity
    }

    static let notProtocolOrClass = MockDiagnostic("'@Mock' can only be attached to a protocol or a class", "notProtocolOrClass")
    static let classTargetUnsupported = MockDiagnostic("'@Mock' on classes is not yet supported; attach it to a protocol", "classTargetUnsupported")
    static func overloadUnsupported(_ name: String) -> MockDiagnostic {
        MockDiagnostic("'@Mock' does not yet support overloaded members ('\(name)' is declared more than once)", "overloadUnsupported")
    }
}
