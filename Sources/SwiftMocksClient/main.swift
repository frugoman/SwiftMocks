import SwiftMocks

// Attach @Mock to a protocol; it generates `ServiceMock` conforming to it — no hand-forwarding.
@Mock
protocol Service {
    var name: String { get }
    var count: Int { get set }
    func perform(with param: Int) -> String
    func load() throws -> Int
    func ping() async
    func fetch(id: Int, tag: String) async throws -> String
}

let service = ServiceMock()

// Stub a property getter and a method.
service.stub.name(returns: "stubbed")
service.stub.perform { param in "mocked => \(param)" }

print(service.name)                       // prints `stubbed`
print(service.perform(with: 1))           // prints `mocked => 1`

// Verify calls.
print(service.verify.perform.calledOnce)          // prints `true`
print(service.verify.perform.calledWith(1))       // prints `true`

// Settable property records assignments.
service.stub.count(returns: 0)
service.count = 42
print(service.verify.countSet.calledWith(42))     // prints `true`

// Sequence + conditional stubbing.
service.stub.perform(inSequence: ["a", "b"])
service.stub.perform(when: .eq(99)) { _ in "ninety-nine" }
print(service.perform(with: 99))          // prints `ninety-nine` (conditional wins)
print(service.perform(with: 1))           // prints `a`
print(service.perform(with: 1))           // prints `b`

// Throwing + async.
enum DemoError: Error { case boom }
service.stub.load(throws: DemoError.boom)
service.stub.fetch { id, tag in "\(id):\(tag)" }

func demoAsync() async {
    let value = try? await service.fetch(id: 7, tag: "x")
    print(value ?? "nil")                 // prints `7:x`
}
await demoAsync()
