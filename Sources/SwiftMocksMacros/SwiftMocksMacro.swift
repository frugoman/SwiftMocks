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

        // Reject protocol features the generator can't yet honour, with a clear message —
        // rather than emitting a mock that fails to conform with a cryptic downstream error.
        if let diagnostic = unsupportedFeature(in: proto) {
            context.diagnose(Diagnostic(node: node, message: diagnostic))
            return []
        }

        let members = proto.memberBlock.members
        let functions = members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
        let properties = members.compactMap { $0.decl.as(VariableDeclSyntax.self) }

        let funcModels = functions.map(FunctionModel.init)
        let propModels = properties.compactMap { PropertyModel($0) }

        let mockName = proto.name.text + "Mock"
        // A single inherited protocol is mocked by subclassing its `<Base>Mock`.
        let baseMock = realBases(of: proto).first.map { $0 + "Mock" }
        let source = render(mockName: mockName, conformsTo: proto.name.text, baseMock: baseMock, functions: funcModels, properties: propModels)
        return [DeclSyntax(stringLiteral: source)]
    }
}

// MARK: - Validation

/// Inherited protocols that carry requirements (i.e. excluding marker/constraint protocols
/// that need no implementation). Each must itself be `@Mock`'d so its mock can be subclassed.
private func realBases(of proto: ProtocolDeclSyntax) -> [String] {
    let markers: Set<String> = ["AnyObject", "Sendable", "Any"]
    return (proto.inheritanceClause?.inheritedTypes ?? [])
        .map { $0.type.trimmedDescription }
        .filter { !markers.contains($0) }
}

/// Returns a diagnostic for the first unsupported feature found in `proto`, or nil if the
/// protocol is fully supported by the generator.
private func unsupportedFeature(in proto: ProtocolDeclSyntax) -> MockDiagnostic? {
    // A single inherited protocol is supported by subclassing its mock (see `baseMock`).
    // Classes are single-inheritance, so two or more real bases can't both be subclassed.
    if realBases(of: proto).count > 1 {
        return .multipleInheritanceUnsupported
    }

    func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
    }

    for member in proto.memberBlock.members {
        let decl = member.decl
        if decl.is(InitializerDeclSyntax.self) { return .initializerUnsupported }
        if decl.is(SubscriptDeclSyntax.self) { return .subscriptUnsupported }
        if decl.is(AssociatedTypeDeclSyntax.self) { return .associatedTypeUnsupported }

        if let function = decl.as(FunctionDeclSyntax.self) {
            if isStatic(function.modifiers) { return .staticUnsupported }
            for param in function.signature.parameterClause.parameters {
                // These can't live in the tracker's argument tuple / stub closure.
                if param.ellipsis != nil { return .variadicUnsupported }
                if param.type.trimmedDescription.hasPrefix("inout ") { return .inoutUnsupported }
            }
        }
        if let variable = decl.as(VariableDeclSyntax.self) {
            if isStatic(variable.modifiers) { return .staticUnsupported }
            // Effectful accessors (`{ get throws }`, `{ get async }`) aren't generated yet.
            for binding in variable.bindings {
                if case .accessors(let accessors)? = binding.accessorBlock?.accessors {
                    if accessors.contains(where: { $0.effectSpecifiers != nil }) {
                        return .effectfulAccessorUnsupported
                    }
                }
            }
        }
    }
    return nil
}

// MARK: - Member models

private struct FunctionModel {
    let name: String
    let paramTypes: [String]
    let paramLabels: [String]       // external argument labels ("_" when unlabelled)
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
        paramLabels = params.map { $0.firstName.text }
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

// MARK: - Overload disambiguation

/// The base name used for a function's tracker, stub methods, and verify accessor. Unique
/// names are left as-is; overloaded names gain a discriminator derived from their parameter
/// labels/types (or return type), so `verify.send_Int` / `verify.send_String` don't collide.
private func accessorNames(for functions: [FunctionModel]) -> [String] {
    let counts = Dictionary(grouping: functions, by: { $0.name }).mapValues { $0.count }
    var used = Set<String>()
    var result: [String] = []
    for f in functions {
        if counts[f.name] == 1 {
            result.append(f.name)
            used.insert(f.name)
            continue
        }
        let disc = discriminator(f)
        var candidate = f.name + "_" + disc
        var suffix = 0
        while used.contains(candidate) {
            candidate = f.name + "_" + disc + "_\(suffix)"
            suffix += 1
        }
        used.insert(candidate)
        result.append(candidate)
    }
    return result
}

private func discriminator(_ f: FunctionModel) -> String {
    func sanitize(_ s: String) -> String {
        String(s.map { $0.isLetter || $0.isNumber ? $0 : "_" })
    }
    let tokens = zip(f.paramLabels, f.paramTypes).map { label, type in
        label != "_" ? label : sanitize(type)
    }
    return tokens.isEmpty ? "ret_" + sanitize(f.returnType) : tokens.joined(separator: "_")
}

// MARK: - Rendering

private func render(mockName: String, conformsTo: String, baseMock: String?, functions: [FunctionModel], properties: [PropertyModel]) -> String {
    var trackers: [String] = []
    var conformance: [String] = []
    var stub: [String] = []
    var verify: [String] = []

    // Each facade level holds its own uniquely-named reference to the mock, so an inheriting
    // mock's facade (a subclass of the base facade) doesn't clash with the base's stored target.
    let target = "_\(mockName)_target"

    // Overloaded members share a base name; give each a unique accessor for its tracker /
    // stub / verify, while the conformance methods keep their real overloaded signatures.
    let accessors = accessorNames(for: functions)
    for (f, accessor) in zip(functions, accessors) {
        let tracker = "_mock_\(accessor)"
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

        stub.append(contentsOf: stubMethods(f, name: accessor, tracker: tracker, target: target))
        verify.append("var \(accessor): \(trackerType)<\(argsType), \(f.returnType)> { \(target).\(tracker) }")
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
            verify.append("var \(p.name)Set: Mock<\(p.type), Void> { \(target).\(setTracker) }")
        } else {
            conformance.append("var \(p.name): \(p.type) { \(getTracker).record(()) }")
        }
        stub.append("func \(p.name)(_ body: @escaping () -> \(p.type)) { \(target).\(getTracker).setStub { _ in body() } }")
        stub.append("func \(p.name)(returns value: \(p.type)) { \(target).\(getTracker).setStub { _ in value } }")
        verify.append("var \(p.name): Mock<Void, \(p.type)> { \(target).\(getTracker) }")
    }

    func indent(_ lines: [String], _ spaces: Int) -> String {
        let pad = String(repeating: " ", count: spaces)
        return lines.joined(separator: "\n").split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : pad + $0 }.joined(separator: "\n")
    }

    // Inheriting mock: subclass the base's mock (inherits its members + trackers) and its facades.
    let inheritList = (baseMock.map { "\($0), " } ?? "") + conformsTo + ", @unchecked Sendable"
    // A non-inheriting mock declares its own init; an inheriting one inherits the base's.
    let body = (baseMock == nil ? ["init() {}", ""] : []) + conformance
    let overrideKw = baseMock == nil ? "" : "override "
    let stubSuper = baseMock.map { ": \($0).Stub" } ?? ""
    let verifySuper = baseMock.map { ": \($0).Verify" } ?? ""
    let superCall = baseMock == nil ? "" : "; super.init(target)"
    let facadeInit = "init(_ target: \(mockName)) { self.\(target) = target\(superCall) }"

    return """
    class \(mockName): \(inheritList) {
    \(indent(trackers, 4))

    \(indent(body, 4))

        \(overrideKw)var stub: Stub { Stub(self) }
        \(overrideKw)var verify: Verify { Verify(self) }

        class Stub\(stubSuper) {
            let \(target): \(mockName)
            \(facadeInit)
    \(indent(stub, 8))
        }

        class Verify\(verifySuper) {
            let \(target): \(mockName)
            \(facadeInit)
    \(indent(verify, 8))
        }
    }
    """
}

private func stubMethods(_ f: FunctionModel, name: String, tracker: String, target: String) -> [String] {
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
    methods.append("func \(name)(_ body: @escaping \(closureType)) { \(target).\(tracker).setStub { a in \(forwardCall) } }")

    if f.returnType != "Void" {
        methods.append("func \(name)(returns value: \(f.returnType)) { \(target).\(tracker).setStub { _ in value } }")
        methods.append("func \(name)(inSequence values: [\(f.returnType)]) { \(target).\(tracker).setSequence(values) }")
    }
    if f.isThrows {
        methods.append("func \(name)(throws error: Error) { \(target).\(tracker).setError(error) }")
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
        methods.append("func \(name)(\(matcherParams), _ body: @escaping \(closureType)) { \(target).\(tracker).setStub(when: { a in \(matchExpr) }, { a in \(forwardCall) }) }")
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
    static let multipleInheritanceUnsupported = MockDiagnostic("'@Mock' supports inheriting from at most one other protocol (which must itself be '@Mock'); flatten the rest into the mocked protocol", "multipleInheritanceUnsupported")
    static let staticUnsupported = MockDiagnostic("'@Mock' does not yet support static requirements", "staticUnsupported")
    static let initializerUnsupported = MockDiagnostic("'@Mock' does not yet support initializer requirements", "initializerUnsupported")
    static let subscriptUnsupported = MockDiagnostic("'@Mock' does not yet support subscript requirements", "subscriptUnsupported")
    static let associatedTypeUnsupported = MockDiagnostic("'@Mock' does not yet support associated types", "associatedTypeUnsupported")
    static let effectfulAccessorUnsupported = MockDiagnostic("'@Mock' does not yet support throwing or async property accessors", "effectfulAccessorUnsupported")
    static let variadicUnsupported = MockDiagnostic("'@Mock' does not yet support variadic parameters", "variadicUnsupported")
    static let inoutUnsupported = MockDiagnostic("'@Mock' does not yet support 'inout' parameters", "inoutUnsupported")
}
