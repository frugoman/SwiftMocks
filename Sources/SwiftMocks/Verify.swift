// Verify Surface conveniences. A generated `verify.<member>` exposes its CallTracker
// directly, so these methods — plus the inherited `calledOnce`, `callsCount`,
// `neverCalled`, `latestCall`, `callsHistory`, `called(where:)` — are all available on it.

public extension CallTracker {
    /// Whether any recorded call's arguments satisfy `matcher`. Works for any argument type,
    /// including multi-argument (tuple) members via `.where { $0.0 == ... }`.
    func calledWith(_ matcher: ArgumentMatcher<Args>) -> Bool {
        called(where: matcher.matches)
    }

    /// Number of recorded calls whose arguments satisfy `matcher`.
    func callCount(matching matcher: ArgumentMatcher<Args>) -> Int {
        callCount(where: matcher.matches)
    }
}

public extension CallTracker where Args: Equatable {
    /// Whether any recorded call was made with arguments equal to `expected`. Available when
    /// the argument type is `Equatable` (single-argument members); multi-argument members use
    /// the matcher form above.
    func calledWith(_ expected: Args) -> Bool {
        called(where: { $0 == expected })
    }
}
