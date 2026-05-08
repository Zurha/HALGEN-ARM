struct DigitalValue {
    var _value: Bool

    @_transparent
    init(_ _value: Bool) {
        self._value = _value
    }

    @inline(__always)
    static var high: DigitalValue { DigitalValue(true) }

    @inline(__always)
    static var low: DigitalValue { DigitalValue(false) }
}

extension DigitalValue: Equatable {
    @inline(__always)
    static func == (lhs: DigitalValue, rhs: DigitalValue) -> Bool {
        return lhs._value == rhs._value
    }
}

extension DigitalValue: Hashable {
    @inline(__always)
    func hash(into hasher: inout Hasher) {
        hasher.combine((self._value ? 1 : 0) as UInt)
    }
}

extension DigitalValue {
    @inline(__always)
    static prefix func ! (lhs: DigitalValue) -> DigitalValue { DigitalValue(!lhs._value) }
}

extension DigitalValue {
    @inline(__always)
    static func && (lhs: DigitalValue, rhs: DigitalValue) -> DigitalValue {
        return DigitalValue(lhs._value && rhs._value)
    }

    @inline(__always)
    static func || (lhs: DigitalValue, rhs: DigitalValue) -> DigitalValue {
        return DigitalValue(lhs._value || rhs._value)
    }
}

extension DigitalValue {
    @inline(__always)
    mutating func toggle() { self._value = !self._value }
}
