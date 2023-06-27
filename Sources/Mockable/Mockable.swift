public struct Mockable<ArgumentType, ReturnType> {
    public typealias CallType = ((ArgumentType) -> ReturnType)
    
    /// Mock block to handle call, and return value. To injected by Tests.
    private var callMock: CallType
    
    
    public init(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        self.init { _ in
            preconditionFailure("Default value or default behaviour expected!")
        }
    }
    
    /// Initialise Mockable with default return value
    /// - Parameter defaultReturnValue: Value to be reutnred automativally by default when record trigered
    public init(defaultReturnValue: ReturnType) {
        callMock = { _ in defaultReturnValue }
    }

    /// Initialise Mockable with mock function
    /// - Parameter mock: escaping mock function to be executed when record tiggered
    public init(mock: @escaping CallType) {
        self.callMock = mock
    }
    
    /// Arguments from last call
    public var latestCall: ArgumentType? {
        callsHistory.last
    }

    /// Number of times records called
    public var callsCount: Int {
        callsHistory.count
    }
    
    /// Update closure to be called when record is tiggered
    /// - Parameter mock: function to be called when `record` tiggered. To be injected by test to validate parameters, override result, trigger expectations etc.
    public mutating func mockCall(_ mock: @escaping CallType) {
        callMock = mock
    }

    /// Keeps track of all the calls that the mock had
    public private(set) var callsHistory: [ArgumentType] = []
    
    /// Record call
    /// - Parameter arguments: tuple with arguments to be recorded
    public mutating func record(_ arguments: ArgumentType) -> ReturnType {
        callsHistory.append(arguments)
        return callMock(arguments)
    }
}

/// Convinience extension to enable parameterless initialiser for no return expected
public extension Mockable where ReturnType == Void {
    init() {
        self.init { _ in }
    }
}

/// Convinience extension to record Void argument
public extension Mockable where ArgumentType == Void {
    /// Update closure to be called when record is tiggered
    /// - Parameter mock: function to be called when `record` tiggered. To be injected by test to validate parameters, override result, trigger expectations etc.
    mutating func mockCall(_ mock: @escaping () -> ReturnType) {
        callMock = { _ in mock() }
    }
    
    mutating func record() -> ReturnType {
        self.record(())
    }
}

/// Simple struct to define Mockables for Variables
public struct MockableVariable<VarType> {
    public var setter: Mockable<VarType, Void>
    public var getter: Mockable<Void, VarType>

    public init() {
        self.setter = .init()
        self.getter = .init()
    }
}
