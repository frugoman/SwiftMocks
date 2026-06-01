# SwiftMocks

A lightweight mocking framework for Swift, powered by macros.

Annotate a protocol with `@Mock` and SwiftMocks generates a ready-to-use mock type — every
method and property implemented for you. No hand-written forwarding, no boilerplate spies.
Configure behaviour through a `.stub` surface and make assertions through a `.verify` surface.

```swift
@Mock
protocol Service {
    func fetch(id: Int) async throws -> String
}

let service = ServiceMock()
service.stub.fetch { id in "loaded-\(id)" }

let value = try await service.fetch(id: 3)        // "loaded-3"
#expect(service.verify.fetch.calledOnce)
#expect(service.verify.fetch.calledWith(.where { $0 == 3 }))
```

## Requirements

- Swift 5.9+ (macros)
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## Installation

Add SwiftMocks to your `Package.swift`:

```swift
.package(url: "https://github.com/frugoman/SwiftMocks.git", from: "1.0.0")
```

and depend on it from your test target:

```swift
.testTarget(name: "MyAppTests", dependencies: ["MyApp", "SwiftMocks"])
```

## Generating a mock

Attach `@Mock` to a protocol. It generates a sibling type named `<Protocol>Mock` that conforms
to the protocol:

```swift
@Mock
protocol Service {
    var name: String { get }
    var retries: Int { get set }
    func perform(with value: Int) -> String
    func reset()
}

let service = ServiceMock()   // conforms to Service
```

Every member forwards into a tracker that records calls and resolves stubs. You never write the
forwarding yourself.

> `@Mock` currently supports **protocols**. Class support is in progress; attaching `@Mock` to a
> class produces a clear compile-time diagnostic for now.

## Stubbing — the `.stub` surface

```swift
// A closure that receives the call's arguments
service.stub.perform { value in "got \(value)" }

// A fixed return value
service.stub.perform(returns: "fixed")

// A different value on each successive call (repeats the last once exhausted)
service.stub.perform(inSequence: ["a", "b", "c"])

// Conditional on the arguments — first matching stub wins, else the fallback above
service.stub.perform(when: .eq(42)) { _ in "forty-two" }
```

For throwing members you can stub an error:

```swift
@Mock protocol Loader { func load() throws -> Data }

loader.stub.load(throws: MyError.notFound)
```

### Returns you don't have to stub

Members returning `Void`, an `Optional`, or an empty `Array` / `Dictionary` / `Set` work as pure
spies — no stub required. Calling any **other** non-stubbed returning member reports a failure,
so a mock never silently runs unexpected behaviour.

## Verifying — the `.verify` surface

`verify.<member>` exposes the call record:

```swift
service.perform(with: 7)

service.verify.perform.calledOnce        // Bool
service.verify.perform.callsCount        // Int
service.verify.perform.neverCalled       // Bool
service.verify.perform.latestCall        // 7
service.verify.perform.callsHistory      // [7]
```

Match arguments with a plain value (when `Equatable`) or a matcher:

```swift
service.verify.perform.calledWith(7)                  // exact value
service.verify.perform.calledWith(.any)               // any value
service.verify.perform.calledWith(.where { $0 > 0 })  // predicate
```

Multi-argument members match on the argument tuple:

```swift
@Mock protocol API { func send(id: Int, tag: String) }

api.verify.send.calledWith(.where { $0.0 == 1 && $0.1 == "x" })
```

## Properties

A `{ get }` property is stubbed and verified through its getter:

```swift
service.stub.name(returns: "Ada")
_ = service.name
service.verify.name.calledOnce
```

A `{ get set }` property also records assignments, verified via `<name>Set`:

```swift
service.stub.retries(returns: 0)
service.retries = 3
service.verify.retriesSet.calledWith(3)   // true
```

## async / throws

Every effect combination is supported, and a stub closure carries the same effects as the member:

```swift
@Mock
protocol Repository {
    func value() async -> Int
    func risky() throws -> Int
    func fetch(id: Int) async throws -> String
}

repo.stub.value(returns: 1)
repo.stub.risky(throws: MyError.boom)
repo.stub.fetch { id in "row-\(id)" }
```

## Failure reporting

Failures that originate inside a mock (such as calling an un-stubbed returning member) are routed
through `SwiftMocks.failureReporter`. By default it traps; you can point it at your test framework:

```swift
SwiftMocks.failureReporter = { message, file, line in
    XCTFail(message, file: file, line: line)
}
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
