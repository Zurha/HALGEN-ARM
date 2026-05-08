public protocol PartialPort {
    associatedtype PortType: BinaryInteger
    static var dataRegister: PortType { get set }
    static var inputAddress: PortType { get }
}

public protocol Port: PartialPort {
    static var dataDirection: PortType { get set }
}

public protocol Bit {
    associatedtype BitType: BinaryInteger
    associatedtype PinMaskType: BinaryInteger
    static var bit: BitType { get }
}

public extension Bit {
    @inline(__always)
    static var pinSetMask: PinMaskType {
        1 << bit
    }

    @inline(__always)
    static var pinClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inline(__always)
    static var pinDirectionSetMask: PinMaskType {
        1 << bit
    }

    @inline(__always)
    static var pinDirectionClearMask: PinMaskType {
        ~(1 << bit)
    }

    @inline(__always)
    static var pinGetMask: PinMaskType {
        1 << bit
    }
}

public protocol PartialPortPin {
    associatedtype PinPartialPort: PartialPort
    associatedtype PinBit: Bit

    static func setValue(_ value: DigitalValue)
    static func value() -> DigitalValue
}

public enum DataDirectionFlag: UInt32 {
    case input, output
}

public protocol PortPin: PartialPortPin where PinPartialPort == PinPort {
    associatedtype PinPort: Port
    static func setDataDirection(_ direction: DataDirectionFlag)
}

public extension PartialPortPin where PinPartialPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
        if value == .high {
            PinPartialPort.dataRegister |= PinBit.pinSetMask
        } else {
            PinPartialPort.dataRegister &= PinBit.pinClearMask
        }
    }

    @inline(__always)
    static func value() -> DigitalValue {
        DigitalValue(PinPartialPort.inputAddress & PinBit.pinGetMask != 0)
    }
}

public extension PortPin where PinPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
        case .input:
            PinPort.dataDirection &= PinBit.pinDirectionClearMask
        case .output:
            PinPort.dataDirection |= PinBit.pinDirectionSetMask
        }
    }
}

// Ports that expose dedicated set/clear registers (e.g. SAMD21 DIRSET/DIRCLR, OUTSET/OUTCLR).
// Conforming types get overriding implementations that avoid read-modify-write.
public protocol AtomicPort: Port {
    static var dataDirectionSet: PortType { get set }
    static var dataDirectionClear: PortType { get set }
    static var dataRegisterSet: PortType { get set }
    static var dataRegisterClear: PortType { get set }
}

public extension PortPin where PinPort: AtomicPort, PinPort.PortType == PinBit.PinMaskType {
    @inline(__always)
    static func setValue(_ value: DigitalValue) {
        if value == .high {
            PinPort.dataRegisterSet = PinBit.pinSetMask
        } else {
            PinPort.dataRegisterClear = PinBit.pinSetMask
        }
    }

    @inline(__always)
    static func setDataDirection(_ direction: DataDirectionFlag) {
        switch direction {
        case .input:
            PinPort.dataDirectionClear = PinBit.pinSetMask
        case .output:
            PinPort.dataDirectionSet = PinBit.pinSetMask
        }
    }
}

public enum DigitalPin<_Port: Port, _Bit: Bit>: PortPin where _Port.PortType == _Bit.PinMaskType {
    public typealias PinPort = _Port
    public typealias PinPartialPort = _Port
    public typealias PinBit = _Bit
}

public enum InputOnlyDigitalPin<_Port: PartialPort, _Bit: Bit>: PartialPortPin where _Port.PortType == _Bit.PinMaskType {
    public typealias PinPartialPort = _Port
    public typealias PinBit = _Bit
}

// bit definitions for AVR
public enum Bit0: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 0 }
}

public enum Bit1: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 1 }
}

public enum Bit2: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 2 }
}

public enum Bit3: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 3 }
}

public enum Bit4: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 4 }
}

public enum Bit5: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 5 }
}

public enum Bit6: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 6 }
}

public enum Bit7: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 7 }
}

public enum Bit8: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 8 }
}

public enum Bit9: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 9 }
}

public enum Bit10: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 10 }
}

public enum Bit11: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 11 }
}

public enum Bit12: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 12 }
}

public enum Bit13: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 13 }
}

public enum Bit14: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 14 }
}

public enum Bit15: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 15 }
}

public enum Bit16: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 16 }
}

public enum Bit17: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 17 }
}

public enum Bit18: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 18 }
}

public enum Bit19: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 19 }
}

public enum Bit20: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 20 }
}

public enum Bit21: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 21 }
}

public enum Bit22: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 22 }
}

public enum Bit23: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 23 }
}

public enum Bit24: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 24 }
}

public enum Bit25: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 25 }
}

public enum Bit26: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 26 }
}

public enum Bit27: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 27 }
}

public enum Bit28: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 28 }
}

public enum Bit29: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 29 }
}

public enum Bit30: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 30 }
}

public enum Bit31: Bit {
    public typealias PinMaskType = UInt32

    @inline(__always)
    public static var bit: UInt32 { 31 }
}
