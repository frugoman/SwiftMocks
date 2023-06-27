/// A macro that generates a mock for a given type.
/// It creates a constant `mock` of the given type that can be used to record calls and mock method calls.
///
/// Example:
/// ```swift
/// @Mock class MyClass {
///     var priority: Int { mock.priority.getter.record() }
///     func doSomething() { mock.doSomething() }
///     func perform(with param: Int) -> String {
///         mock.perform(with: param)
///     }
/// }
/// ```
///
/// The generated code by the macro will look like this:
///
/// ```swift
/// class MyClass {
///     struct MyClassMockable {
///         var priority: MockableVariable<Int> = .init()
///         var doSomethingCalls: Mockable<Void, Void> = .init()
///         var performCalls: Mockable<Int, String> = .init()
///     }
///     var mock: MyClassMockable = .init()
/// }
/// ```
///
/// The generated code can be used like this:
///
/// ```swift
/// let myClass = MyClass()
/// myClass.mock.priority.getter.mockCall { 1 }
/// print(myClass.priority) // prints `1`
/// myClass.doSomething()
/// print(myClass.mock.doSomethingCalls.callsCount == 1) // prints `true`
/// myClass.mock.performCalls.mockCall { param in "mocked => \(param)" }
/// print(myClass.perform(with: 1)) // prints `mocked => 1`
/// ```
///
@attached(member, names: arbitrary)
public macro Mock() = #externalMacro(
    module: "MockableMacros",
    type: "MockableMacro"
)