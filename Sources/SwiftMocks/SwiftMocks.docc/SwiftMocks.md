# ``SwiftMocks``

A lightweight mocking framework for Swift, powered by macros.

## Overview

Annotate a protocol with ``Mock()`` and SwiftMocks generates a ready-to-use mock type — every
method and property implemented for you. Configure behaviour through a `.stub` surface and make
assertions through a `.verify` surface.

```swift
@Mock
protocol Service {
    func fetch(id: Int) async throws -> String
}

let service = ServiceMock()
service.stub.fetch { id in "loaded-\(id)" }

let value = try await service.fetch(id: 3)        // "loaded-3"
service.verify.fetch.calledOnce                   // true
service.verify.fetch.calledWith(.where { $0 == 3 })
```

A stub closure carries the same effects (`async` / `throws`) as the member it stubs, and members
returning `Void`, an `Optional`, or an empty collection need no stub at all.

## Topics

### Generating a mock

- ``Mock()``

### Call trackers

The generated mock forwards each member into one of these, picked by the member's effects:

- ``Mock``
- ``ThrowingMock``
- ``AsyncMock``
- ``AsyncThrowingMock``
- ``CallTracker``

### Matching arguments

- ``ArgumentMatcher``

### Failure reporting

- ``SwiftMocks``
