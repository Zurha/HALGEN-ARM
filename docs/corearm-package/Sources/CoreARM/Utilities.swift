/// Issues a single `nop` instruction.
@inline(__always)
public func noOperation() {
    _noOpperation()
}

/// Issues a single `nop` instruction.
@available(*, deprecated, renamed: "noOperation()")
@inline(__always)
public func noOpperation() {
    noOperation()
}

/// Runs a critical section wrapper used by generated 16-bit register accessors.
@inline(__always)
public func atomic<T>(block: () -> T) -> T {
    block()
}
