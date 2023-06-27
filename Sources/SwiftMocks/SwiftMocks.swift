/// Mock is a lightweight mocking framework for Swift.
/// It allows to mock calls to functions and methods, and inspect the calls made to them.
///
/// For example:
///
///     class MyClass {
///         let mock = Mock<(Int, String), String>()
///         func doAction(number: Int, text: String) -> String {
///             return mock.record((number, text))
///         }
///     }
///
public struct Mock<ArgumentType, ReturnType> {
    public typealias CallType = ((ArgumentType) -> ReturnType)
    
    private var callMock: CallType
    
    /// Creates a mock that will fail if called without being mocked.
    public init(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        self.init { _ in
            preconditionFailure("Default value or default behaviour expected!")
        }
    }
    
    /// Creates a mock that will return the given default value if
    /// called without being mocked.
    /// - Parameter defaultReturnValue: The value to return when called without being mocked.
    ///
    /// - Note: Useful for mocking functions that return a value and don't have side effects.
    public init(defaultReturnValue: ReturnType) {
        callMock = { _ in defaultReturnValue }
    }

    /// Creates a mock that will behave as the given mocked function.
    /// - Parameter mock: The function to be executed when the mock is called.
    ///
    /// - Note: Useful for mocking functions that have side effects
    ///         and you want to test the side effects.
    public init(mock: @escaping CallType) {
        self.callMock = mock
    }
    
    /// Returns the arguments of the last call made to the mock or `nil` if no calls were made.
    public var latestCall: ArgumentType? {
        callsHistory.last
    }

    /// Returns the number of calls made to the mock.
    public var callsCount: Int {
        callsHistory.count
    }
    
    /// Injects a mock to be executed when the mock is called.
    ///
    /// For example:
    ///
    ///     let mock = Mock<(Int, String), String>()
    ///     mock.mockCall { (number, text) in "\(number) \(text)" }
    ///     mock.record((1, "2")) // returns "1 2"
    ///
    /// - Parameter mock: The function to be executed when the mock is called.
    public mutating func mockCall(_ mock: @escaping CallType) {
        callMock = mock
    }

    /// Returns the list of arguments of all the calls made to the mock.
    /// For example
    ///
    ///     let mock = Mock<(Int, String), String>()
    ///     mock.record((1, "2"))
    ///     mock.record((3, "4"))
    ///     mock.callsHistory // returns [(1, "2"), (3, "4")]
    ///
    /// - Note: The order of the arguments is the same as the order of the calls.
    public private(set) var callsHistory: [ArgumentType] = []
    
    /// Records a call to the mock and returns the result of the mock.
    /// - Parameter arguments: The arguments of the call.
    /// - Returns: The result of the mock.
    ///
    /// For example:
    ///
    ///     let mock = Mock<(Int, String), String>()
    ///     mock.record((1, "2")) // returns the result of the mock
    ///
    /// Further example:
    ///
    ///     class MyClass {
    ///         let mock = Mock<(Int, String), String>()
    ///         func doAction(number: Int, text: String) -> String {
    ///             return mock.record((number, text))
    ///         }
    ///     }
    ///     let myClass = MyClass()
    ///     myClass.mock.mockCall { (number, text) in "\(number) \(text)" }
    ///     myClass.doAction(number: 1, text: "2") // returns "1 2", as the mock was injected
    ///     myClass.mock.callsHistory // returns [(1, "2")]
    ///
    public mutating func record(_ arguments: ArgumentType) -> ReturnType {
        callsHistory.append(arguments)
        return callMock(arguments)
    }
}

public extension Mock where ReturnType == Void {
    /// Convenience initializer for mocks that return `Void`.
    /// - Note: The mock will fail if called without being mocked.
    ///       Call `mockCall(_:)` to inject a mock.
    /// - SeeAlso: `init(file:line:)`
    init() {
        self.init { _ in }
    }
}

public extension Mock where ArgumentType == Void {
    /// Convenience method for mocking functions that don't take arguments.
    /// - Parameter mock: The function to be executed when the mock is called.
    /// - SeeAlso: `mockCall(_:)`
    /// - Note: Same as calling `mockCall { _ in mock() }` but more readable.
    mutating func mockCall(_ mock: @escaping () -> ReturnType) {
        callMock = { _ in mock() }
    }
    
    /// Convenience method for recording calls to functions that don't take arguments.
    /// - Returns: The result of the mock.
    /// - SeeAlso: `record(_:)`
    /// - Note: Same as calling `record(())` but more readable.
    mutating func record() -> ReturnType {
        self.record(())
    }
}

/// A mock better suited for mocking properties.
///
/// For example:
///
/// 	class MyClass {
/// 	    let mock = MockVariable<String>()
/// 	    var myProperty: String {
/// 	        get { return mock.getter.record() }
/// 	        set { mock.setter.record(newValue) }
/// 	    }
/// 	}
///
public struct MockVariable<VarType> {
    public var setter: Mock<VarType, Void>
    public var getter: Mock<Void, VarType>

    /// Creates a mock that will fail if called without being mocked.
    /// - Note: You can inject mocks by calling `mockCall(_:)` on `setter` or `getter`.
    ///       i.e. `mock.getter.mockCall { "Hello" }`
    public init() {
        self.setter = .init()
        self.getter = .init()
    }
}
