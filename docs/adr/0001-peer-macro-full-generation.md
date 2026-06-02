# Peer-macro full generation, replacing member-macro hand-forwarding

Status: accepted

## Context

The original `@Mock` was an `@attached(member)` macro: it generated a nested `XMock`
struct and call-trackers *inside* the annotated class, but a member macro cannot rewrite a
method body, so users still had to hand-write the forwarding call sites
(`func f() { mock.f() }`). That manual forwarding is the very boilerplate the library exists
to remove, and it is error-prone (easy to forward the wrong arguments).

## Decision

Pivot `@Mock` to an `@attached(peer)` macro that generates a **sibling Mock Type** with all
bodies written for you — no hand-forwarding.

- **One** `@Mock` attribute; it branches internally on the attached declaration kind.
- **Protocol target (primary):** generates `class XMock: X` implementing every requirement.
- **Class target (secondary):** generates `class XMock: X` overriding members. Valid only if
  every member is overridable; `final`/stored/`private`/`static`/`init` members are a
  **compile error**, never a silent pass-through.
- The Mock Type exposes a split **`.stub`** surface (configure behaviour) and **`.verify`**
  surface (assert on recorded calls), both facades over the same recorded state.
- All four **Effect Signatures** (sync / throws / async / async throws) are supported; stub
  closures match the member's effects.
- Core has **no test-framework dependency**: in-call failures (e.g. unstubbed non-trivial
  return) route through a pluggable Failure Reporter, with thin `SwiftMocksXCTest` /
  `SwiftMocksTesting` adapters. Verify assertions return `Bool` and are checked by the
  test's own `#expect`/`XCTAssert`.

See [CONTEXT.md](../../CONTEXT.md) for the canonical glossary.

## Considered alternatives

- **Keep the member macro, add codegen tricks** — rejected: a member macro fundamentally
  cannot supply the forwarding bodies, so hand-forwarding would remain.
- **Two macros (`@Mock` for protocols, `@MockClass` for classes)** — rejected: the user's
  mental model is "mock this thing"; one attribute is simpler. Capability differences are
  enforced by diagnostics, not by attribute choice.
- **Deprecation bridge keeping the old path for a version** — rejected: maintaining two
  codegen paths is exactly the tax we are removing for a pre-1.0, small-userbase library.

## Consequences

- **Breaking change.** The old `@Mock class { mock.foo() }` style is removed outright. This
  ships as a **major version (1.0.0)** — the redesign defines the real product — with a short
  before/after migration note in the README.
- Class mocking is deliberately partial; protocols are the blessed path.
