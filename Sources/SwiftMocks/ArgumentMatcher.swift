/// A predicate over a single argument value, used on the Verify Surface and for conditional
/// stubbing. The common case — an exact `Equatable` match — has a plain-value shortcut via
/// `.eq`; for non-`Equatable` arguments only `.any` and `.where` are available.
public struct ArgumentMatcher<Value> {
    private let predicate: (Value) -> Bool

    public init(_ predicate: @escaping (Value) -> Bool) {
        self.predicate = predicate
    }

    /// Whether `value` satisfies this matcher.
    public func matches(_ value: Value) -> Bool { predicate(value) }

    /// Matches any value.
    public static var any: ArgumentMatcher { ArgumentMatcher { _ in true } }

    /// Matches values satisfying `predicate`.
    public static func `where`(_ predicate: @escaping (Value) -> Bool) -> ArgumentMatcher {
        ArgumentMatcher(predicate)
    }
}

public extension ArgumentMatcher where Value: Equatable {
    /// Matches values equal to `value`.
    static func eq(_ value: Value) -> ArgumentMatcher {
        ArgumentMatcher { $0 == value }
    }
}
