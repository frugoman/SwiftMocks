@attached(member, names: arbitrary)
public macro Mock() = #externalMacro(
    module: "MockableMacros",
    type: "MockableMacro"
)