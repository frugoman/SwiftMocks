# SwiftMocks — Context

A macro-based mocking framework for Swift. `@Mock` generates a ready-to-use mock type
for testing, eliminating hand-written spy/stub boilerplate.

## Glossary

### `@Mock`
The single attribute macro that drives the library. Attached to a **protocol** (primary)
or a **class** (secondary), it generates a sibling **Mock Type** that can be used in tests.
There is exactly one such macro; it branches internally on the kind of declaration it is
attached to rather than exposing separate attributes per target.

### Mock Type
The generated sibling type (e.g. `ServiceMock` for `Service`). Conforms to the annotated
protocol (or subclasses the annotated class) and exposes its controls through two
namespaces: the **Stub Surface** and the **Verify Surface**.

### Stub Surface
The `.stub` namespace on a Mock Type. Used to configure behaviour — e.g.
`serviceMock.stub.fetch { "value" }`. This is where return values, sequences, and thrown
errors are wired up.

### Verify Surface
The `.verify` namespace on a Mock Type. Used to make assertions about recorded calls —
e.g. `serviceMock.verify.fetch.calledOnce`. Read-only; never changes behaviour.

The Stub Surface and Verify Surface are two facades over the **same** underlying recorded
state for each member — stubbing and verification always refer to the same calls.

### Mock Target
The declaration `@Mock` is attached to. Two kinds, with different status:

- **Protocol target (primary)** — the idiomatic, fully supported case. Every requirement
  is generated on the conforming Mock Type.
- **Class target (secondary)** — supported with documented limits. The Mock Type subclasses
  the annotated class and overrides its members. A class target is only valid if **every**
  member can be intercepted by overriding. Members that cannot be overridden — `final`,
  stored properties, `private`/`fileprivate`, `static`/`class` members — are a **compile
  error**, not a silent skip. The fix is to make the member computed/overridable, or extract
  a protocol. Initializers are **inherited** (the mock is constructed just like the class),
  not mocked.

A Mock Type never silently passes a call through to a real implementation; if it can't
intercept a member, compilation fails.

### Argument Matcher
A value used on the Verify Surface (and in conditional stubbing) to decide whether a
recorded argument qualifies. The common case is a plain `Equatable` value meaning "equals
this"; matchers cover the rest: `.any`, and `.where { predicate }`. For arguments that are
not `Equatable`, only the matcher form is available — there is no plain-value shortcut.

### Trivially-Defaulted Return
A return type the Mock Type can satisfy without a stub: `Void`, `Optional`, `Array`,
`Dictionary`, `Set`. Members with these returns act as pure spies and need no stubbing.
Any other return type, if its member is called without a stub, produces a reported failure.

### Failure Reporter
The framework-agnostic sink for failures that originate inside a Mock Type mid-call (e.g.
an unstubbed non-trivial call). The core library has no test-framework dependency; thin
adapters route the reporter to `XCTFail` (XCTest) or `Issue.record` (swift-testing).
Verify Surface assertions, by contrast, return `Bool` and are checked by the test's own
`#expect`/`XCTAssert`, so they need no reporter.

### Effect Signature
The `(async, throws)` combination of a mocked member. All four combinations are supported,
and a stub closure carries the **same** effect signature as the member it stubs — stubbing
an `async throws` member gives an `async throws` closure.

### Stub
A configured behaviour for a member, set via the Stub Surface. A stub may be:
- a **single** value or closure,
- a **sequence** — successive calls return successive values,
- an **error** — throwing/async-throwing members can be stubbed to throw,
- a **Conditional Stub** — a behaviour that only applies when the call's arguments satisfy
  given Argument Matchers (e.g. `stub.fetch(when: 1) { ... }`). Multiple conditional stubs
  can coexist on one member; an unconditional stub is the fallback.
