//
//  WDTGenerator.swift
//  SwiftAVRGenerator
//
//  Created by Friso De Backer on 20/04/2026.
//

import Foundation

struct WDTGenerator {
    func generate(device: SVDDevice) -> GeneratedSwiftFile? {
        guard let peripheral = device.peripherals.first(where: { $0.name == "WDT" }),
              let baseAddress = peripheral.baseAddress else {
            return nil
        }

        let source = render(device: device, peripheral: peripheral, baseAddress: baseAddress)

        return GeneratedSwiftFile(
            relativePath: "\(device.name)/Peripherals/WDT.swift",
            contents: source
        )
    }

    private func render(device: SVDDevice, peripheral: SVDPeripheral, baseAddress: UInt64) -> String {
        var lines: [String] = [
            "//",
            "//  WDT.swift",
            "//  HALGEN",
            "//",
            "//  Generated from \(device.name).svd",
            "//",
            "",
            "import Foundation",
            "",
            "public enum WDT {",
            "    public static let baseAddress: UInt32 = \(hexLiteral(baseAddress, bitWidth: 32))",
        ]

        if let description = peripheral.description, description.isEmpty == false {
            lines.append("    public static let description = \(swiftStringLiteral(description))")
        }

        if let interrupt = peripheral.interrupts.first?.value {
            lines.append("    public static let interrupt = \(interrupt)")
        }

        if let interruptName = peripheral.interrupts.first?.name, interruptName.isEmpty == false {
            lines.append("    public static let interruptName = \(swiftStringLiteral(interruptName))")
        }

        for register in peripheral.registers.sorted(by: registerSort) {
            lines.append("")
            lines.append(contentsOf: renderRegister(register, defaultAccess: effectiveDeviceAccess(for: device)))
        }

        lines.append("}")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private func renderRegister(_ register: SVDRegister, defaultAccess: String) -> [String] {
        let size = register.size ?? 32
        let integerType = swiftIntegerType(forBitWidth: size)
        let access = effectiveAccess(register.access, defaultAccess: defaultAccess)
        var lines: [String] = []

        if let description = register.description, description.isEmpty == false {
            lines.append("    /// \(description)")
        }

        lines.append("    public enum \(sanitizedTypeName(register.name)) {")

        if let offset = register.addressOffset {
            lines.append("        public static let offset: UInt32 = \(hexLiteral(offset, bitWidth: 32))")
            lines.append("        public static let address: UInt32 = WDT.baseAddress + offset")
        }

        lines.append("        public static let sizeInBits = \(size)")
        lines.append("        public static let access = \(swiftStringLiteral(access))")

        if let resetValue = register.resetValue {
            lines.append("        public static let resetValue: \(integerType) = \(hexLiteral(resetValue, bitWidth: size))")
        }

        for field in register.fields {
            lines.append("")
            lines.append(contentsOf: renderField(field, registerType: integerType, registerBitWidth: size))
        }

        lines.append("    }")

        return lines
    }

    private func renderField(_ field: SVDField, registerType: String, registerBitWidth: Int) -> [String] {
        let bitOffset = field.bitOffset ?? 0
        let bitWidth = field.bitWidth ?? 0
        let mask = bitMask(offset: bitOffset, width: bitWidth)
        var lines: [String] = []

        if let description = field.description, description.isEmpty == false {
            lines.append("        /// \(description)")
        }

        lines.append("        public enum \(sanitizedTypeName(field.name)) {")
        lines.append("            public static let offset: UInt8 = \(bitOffset)")
        lines.append("            public static let width: UInt8 = \(bitWidth)")
        lines.append("            public static let mask: \(registerType) = \(hexLiteral(mask, bitWidth: registerBitWidth))")

        if let access = field.access, access.isEmpty == false {
            lines.append("            public static let access = \(swiftStringLiteral(access))")
        }

        for enumeratedValues in field.enumeratedValues where enumeratedValues.values.isEmpty == false {
            lines.append("")
            lines.append(contentsOf: renderEnumeratedValues(enumeratedValues, registerType: registerType))
        }

        lines.append("        }")

        return lines
    }

    private func renderEnumeratedValues(_ enumeratedValues: SVDEnumeratedValues, registerType: String) -> [String] {
        let rawType = rawValueType(for: registerType)
        var lines: [String] = ["            public enum Values: \(rawType) {"]

        for value in enumeratedValues.values {
            let caseName = sanitizedCaseName(value.name, fallbackValue: value.value, fallbackDescription: value.description)

            if let description = value.description, description.isEmpty == false {
                lines.append("                /// \(description)")
            }

            let literal = value.value.map { hexLiteral($0, bitWidth: 8) } ?? (value.rawValue ?? "0")
            lines.append("                case \(caseName) = \(literal)")
        }

        lines.append("            }")
        return lines
    }

    private func effectiveDeviceAccess(for device: SVDDevice) -> String {
        effectiveAccess(device.access, defaultAccess: "read-write")
    }

    private func effectiveAccess(_ access: String?, defaultAccess: String) -> String {
        if let access, access.isEmpty == false {
            return access
        }

        return defaultAccess
    }

    private func registerSort(_ lhs: SVDRegister, _ rhs: SVDRegister) -> Bool {
        let lhsOffset = lhs.addressOffset ?? 0
        let rhsOffset = rhs.addressOffset ?? 0

        if lhsOffset == rhsOffset {
            return lhs.name < rhs.name
        }

        return lhsOffset < rhsOffset
    }

    private func swiftIntegerType(forBitWidth bitWidth: Int) -> String {
        switch bitWidth {
        case ...8:
            return "UInt8"
        case ...16:
            return "UInt16"
        case ...32:
            return "UInt32"
        default:
            return "UInt64"
        }
    }

    private func rawValueType(for registerType: String) -> String {
        registerType
    }

    private func bitMask(offset: Int, width: Int) -> UInt64 {
        guard width > 0 else {
            return 0
        }

        if width >= 64 {
            return UInt64.max
        }

        let baseMask = (UInt64(1) << UInt64(width)) - 1
        return baseMask << UInt64(offset)
    }

    private func hexLiteral(_ value: UInt64, bitWidth: Int) -> String {
        let minimumDigits = max(2, ((bitWidth + 3) / 4))
        let raw = String(value, radix: 16, uppercase: true)
        let padded = raw.count < minimumDigits
            ? String(repeating: "0", count: minimumDigits - raw.count) + raw
            : raw

        return "0x\(padded)"
    }

    private func swiftStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }

        return encoded
    }

    private func sanitizedTypeName(_ rawValue: String) -> String {
        sanitizeIdentifier(rawValue, fallback: "Value", style: .upperCamel)
    }

    private func sanitizedCaseName(_ rawValue: String, fallbackValue: UInt64?, fallbackDescription: String?) -> String {
        let candidate: String

        if rawValue.hasPrefix("0x") || rawValue.first?.isNumber == true {
            if let fallbackDescription, fallbackDescription.isEmpty == false {
                candidate = fallbackDescription
            } else if let fallbackValue {
                candidate = "value\(hexLiteral(fallbackValue, bitWidth: 8))"
            } else {
                candidate = "value"
            }
        } else {
            candidate = rawValue
        }

        return sanitizeIdentifier(candidate, fallback: "value", style: .lowerCamel)
    }

    private func sanitizeIdentifier(_ rawValue: String, fallback: String, style: IdentifierStyle) -> String {
        let separated = rawValue
            .replacingOccurrences(of: "0x", with: "0x ")
            .replacingOccurrences(of: "0X", with: "0x ")
            .split { character in
                character.isLetter == false && character.isNumber == false
            }
            .map(String.init)
            .filter { $0.isEmpty == false }

        let tokens = separated.isEmpty ? [fallback] : separated
        let identifier: String

        switch style {
        case .upperCamel:
            identifier = tokens.map(capitalize).joined()
        case .lowerCamel:
            identifier = tokens.enumerated().map { index, token in
                index == 0 ? lowercaseInitial(token) : capitalize(token)
            }.joined()
        }

        let cleanedIdentifier = identifier.isEmpty ? fallback : identifier

        if let first = cleanedIdentifier.first, first.isNumber {
            return style == .upperCamel ? capitalize(fallback) + cleanedIdentifier : fallback + capitalize(cleanedIdentifier)
        }

        return cleanedIdentifier
    }

    private func capitalize(_ value: String) -> String {
        guard let first = value.first else {
            return value
        }

        return first.uppercased() + value.dropFirst().lowercased()
    }

    private func lowercaseInitial(_ value: String) -> String {
        guard let first = value.first else {
            return value
        }

        return first.lowercased() + value.dropFirst().lowercased()
    }
}

private enum IdentifierStyle {
    case upperCamel
    case lowerCamel
}
