//
//  RegisterGenerator.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 26/02/2026.
//

import Foundation

enum SVDRegisterWriteBehavior {
    case normal
    case writeOneToClear
}

/// Generates a Swift property for an SVD register and all supported bitfield accessors.
///
/// This mirrors the AVR generator shape: peripheral generators decide which registers
/// to include, while the shared register/bitfield generators do the repetitive source
/// construction from SVD plus supplemental documentation data.
func generateSVDRegister(
    register: SVDRegister,
    baseName: String,
    indentation: Int,
    writeBehavior: SVDRegisterWriteBehavior = .normal,
    registerData: (_ register: SVDRegister) -> SupplementalRegisterData,
    bitfieldData: (_ field: SVDField) -> SupplementalBitfieldData
) -> String {
    guard let addressOffset = register.addressOffset else {
        return ""
    }

    let supplementalRegisterData = registerData(register)
    let variableName = supplementalRegisterData.variableName.isEmpty
        ? svdRegisterVariableName(for: register)
        : supplementalRegisterData.variableName

    let access = supplementalRegisterData.access.isEmpty ? register.access ?? "read-write" : supplementalRegisterData.access
    let registerSize = register.size ?? 32
    let addressExpression = svdRegisterAddressExpression(baseName: baseName, offset: addressOffset)
    let spaces = String(repeating: " ", count: indentation)
    let getter = svdIndent(
        buildSVDRegisterGetter(
            addressExpression: addressExpression,
            offset: addressOffset,
            registerSize: registerSize
        ),
        by: indentation + 4
    )
    let setter = svdAccessIsReadOnly(access) ? "" : svdIndent(
        buildSVDRegisterSetter(
            addressExpression: addressExpression,
            offset: addressOffset,
            registerSize: registerSize,
            writeBehavior: writeBehavior
        ),
        by: indentation + 4
    )
    let registerDocumentation = svdRegisterDocumentation(
        register: register,
        supplementalData: supplementalRegisterData,
        indentation: indentation
    )
    let bitfields = generateSVDBitfieldAccessors(
        register: register,
        parentExpression: variableName,
        indentation: indentation,
        writeBehavior: writeBehavior,
        bitfieldData: bitfieldData
    )

    return """
    \(registerDocumentation)
    \(spaces)@inline(__always)
    \(spaces)static var \(variableName): UInt32 {
    \(getter)
    \(setter)
    \(spaces)}

    \(bitfields)
    """
}

func buildSVDRegisterGetter(addressExpression: String, offset: UInt64, registerSize: Int) -> String {
    switch registerSize {
    case 8:
        return """
        get {
            UInt32(UnsafeMutablePointer<UInt8>(bitPattern: \(addressExpression))!.pointee)
        }
        """
    case 16:
        return """
        get {
            UInt32(UnsafeMutablePointer<UInt16>(bitPattern: \(addressExpression))!.pointee)
        }
        """
    default:
        return """
        get {
            _volatileRegisterReadUInt32(\(addressExpression))
        }
        """
    }
}

func buildSVDRegisterSetter(
    addressExpression: String,
    offset: UInt64,
    registerSize: Int,
    writeBehavior: SVDRegisterWriteBehavior
) -> String {
    if writeBehavior == .writeOneToClear {
        return buildSVDDirectRegisterSetter(
            addressExpression: addressExpression,
            offset: offset,
            registerSize: registerSize
        )
    }

    switch registerSize {
    case 8:
        return """
        set {
            UnsafeMutablePointer<UInt8>(bitPattern: \(addressExpression))!.pointee = UInt8(newValue & 0xFF)
        }
        """
    case 16:
        return """
        set {
            UnsafeMutablePointer<UInt16>(bitPattern: \(addressExpression))!.pointee = UInt16(newValue & 0xFFFF)
        }
        """
    default:
        return """
        set {
            _volatileRegisterWriteUInt32(\(addressExpression), newValue)
        }
        """
    }
}

func buildSVDDirectRegisterSetter(addressExpression: String, offset: UInt64, registerSize: Int) -> String {
    switch registerSize {
    case 8:
        return """
        set {
            UnsafeMutablePointer<UInt8>(bitPattern: \(addressExpression))!.pointee = UInt8(newValue & 0xFF)
        }
        """
    case 16:
        return """
        set {
            UnsafeMutablePointer<UInt16>(bitPattern: \(addressExpression))!.pointee = UInt16(newValue & 0xFFFF)
        }
        """
    default:
        return """
        set {
            _volatileRegisterWriteUInt32(\(addressExpression), newValue)
        }
        """
    }
}

func svdRegisterAddressExpression(baseName: String, offset: UInt64) -> String {
    guard offset != 0 else {
        return baseName
    }

    return "\(baseName) + \(hexLiteral(offset))"
}

func svdAddressExpressionBase(_ addressExpression: String) -> String {
    String(addressExpression.split(separator: "+", maxSplits: 1).first ?? Substring(addressExpression))
        .trimmingCharacters(in: .whitespaces)
}

func svdIndent(_ text: String, by spaces: Int) -> String {
    let prefix = String(repeating: " ", count: spaces)

    return text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in
            line.isEmpty ? "" : prefix + line
        }
        .joined(separator: "\n")
}

func svdAccessIsReadOnly(_ access: String?) -> Bool {
    switch access?.lowercased() {
    case "read-only", "r":
        return true
    default:
        return false
    }
}

func svdRegisterDocumentation(
    register: SVDRegister,
    supplementalData: SupplementalRegisterData,
    indentation: Int
) -> String {
    if supplementalData.isMissing == false,
       supplementalData.documentation.isEmpty == false {
        return svdIndent(makeDocumentationComment(body: supplementalData.documentation), by: indentation) + "\n"
    }

    let description = register.description ?? register.name
    var lines = ["/// \(description) - \(register.name)"]

    for field in register.fields {
        guard let fieldDescription = field.description else {
            continue
        }

        lines.append("/// \(field.name): \(fieldDescription)")
    }

    return svdIndent(lines.joined(separator: "\n"), by: indentation) + "\n"
}

func svdRegisterVariableName(for register: SVDRegister) -> String {
    swiftMemberIdentifier(from: register.displayName ?? register.name)
}
