/// A macro that generates a **Mock Type** for the annotated declaration.
///
/// Attach `@Mock` to a **protocol** (primary) or a **class** (secondary). It generates a
/// sibling type — e.g. `ServiceMock` for `Service` — that conforms to the protocol (or
/// subclasses the class) with every member implemented for you. No hand-forwarding.
///
/// The generated Mock Type exposes two namespaces:
/// - `.stub` — configure behaviour (`mock.stub.fetch { "value" }`)
/// - `.verify` — assert on recorded calls (`mock.verify.fetch.calledOnce`)
///
/// Example:
/// ```swift
/// @Mock protocol Service {
///     func fetch(id: Int) async throws -> Data
/// }
///
/// let mock = ServiceMock()
/// mock.stub.fetch { id in Data() }
/// let data = try await mock.fetch(id: 1)
/// #expect(mock.verify.fetch.calledOnce)
/// ```
@attached(peer, names: suffixed(Mock))
public macro Mock() = #externalMacro(
    module: "SwiftMocksMacros",
    type: "SwiftMocksMacro"
)
