//
//  BitfieldGenerator.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 26/02/2026.
//

import Foundation

func svdBitfieldAccessorType(bitWidth: Int) -> String {
    bitWidth == 1 ? "Bool" : "UInt32"
}

func svdBitfieldMask(bitWidth: Int) -> UInt64 {
    guard bitWidth > 0 else {
        return 0
    }

    guard bitWidth < UInt64.bitWidth else {
        return UInt64.max
    }

    return (UInt64(1) << UInt64(bitWidth)) - 1
}

func svdBitfieldGetterExpression(parentExpression: String, bitOffset: Int, bitWidth: Int) -> String {
    if bitWidth == 1 {
        return "(\(parentExpression) & (UInt32(1) << \(bitOffset))) != 0"
    }

    return "(\(parentExpression) >> \(bitOffset)) & \(hexLiteral(svdBitfieldMask(bitWidth: bitWidth)))"
}

func generateSVDBitfieldAccessors(
    register: SVDRegister,
    parentExpression: String,
    indentation: Int,
    writeBehavior: SVDRegisterWriteBehavior = .normal,
    bitfieldData: (_ field: SVDField) -> SupplementalBitfieldData
) -> String {
    guard register.fields.isEmpty == false else {
        return ""
    }

    let spaces = String(repeating: " ", count: indentation)
    var code = ""

    for field in register.fields {
        guard let bitOffset = field.bitOffset,
              let bitWidth = field.bitWidth else {
            continue
        }

        let supplementalBitfieldData = bitfieldData(field)
        let fieldName = supplementalBitfieldData.variableName.isEmpty
            ? svdBitfieldVariableName(for: field)
            : supplementalBitfieldData.variableName

        let fieldType = supplementalBitfieldData.valueType.isEmpty
            ? svdBitfieldAccessorType(bitWidth: bitWidth)
            : supplementalBitfieldData.valueType
        let fieldDocumentation = svdBitfieldDocumentation(
            field: field,
            supplementalData: supplementalBitfieldData,
            indentation: indentation
        )
        let getterExpr = svdBitfieldGetterSource(
            fieldType: fieldType,
            defaultValue: supplementalBitfieldData.defaultValue,
            parentExpression: parentExpression,
            bitOffset: bitOffset,
            bitWidth: bitWidth
        )
        let setterExpr = supplementalBitfieldData.access == .read || svdAccessIsReadOnly(register.access)
            ? nil
            : svdBitfieldSetterSource(
                fieldType: fieldType,
                parentExpression: parentExpression,
                bitOffset: bitOffset,
                bitWidth: bitWidth,
                writeBehavior: writeBehavior
            )
        let getterBody = svdIndent(getterExpr, by: indentation + 8)
        let setterBody = setterExpr.map { svdIndent($0, by: indentation + 8) }

        code += """
        \(fieldDocumentation)
        \(spaces)@inline(\(supplementalBitfieldData.inline))
        \(spaces)static var \(fieldName): \(fieldType) {
        \(spaces)    get {
        \(getterBody)
        \(spaces)    }
        \(setterBody.map { """
        \(spaces)    set {
        \($0)
        \(spaces)    }
        """ } ?? "")
        \(spaces)}

        """
    }

    return code
}

private func svdBitfieldDocumentation(
    field: SVDField,
    supplementalData: SupplementalBitfieldData,
    indentation: Int
) -> String {
    if supplementalData.isMissing == false,
       supplementalData.documentation.isEmpty == false {
        return svdIndent(makeDocumentationComment(body: supplementalData.documentation), by: indentation)
    }

    return String(repeating: " ", count: indentation) + "/// \(field.description ?? field.name)"
}

private func svdBitfieldVariableName(for field: SVDField) -> String {
    swiftMemberIdentifier(from: field.name)
}

private func svdBitfieldGetterSource(
    fieldType: String,
    defaultValue: String,
    parentExpression: String,
    bitOffset: Int,
    bitWidth: Int
) -> String {
    switch fieldType {
    case "Bool":
        return "(\(parentExpression) & (UInt32(1) << \(bitOffset))) != 0"
    case "UInt32":
        return "(\(parentExpression) >> \(bitOffset)) & \(hexLiteral(svdBitfieldMask(bitWidth: bitWidth)))"
    case "UInt16":
        return "UInt16((\(parentExpression) >> \(bitOffset)) & \(hexLiteral(svdBitfieldMask(bitWidth: bitWidth))))"
    case "UInt8":
        return "UInt8((\(parentExpression) >> \(bitOffset)) & \(hexLiteral(svdBitfieldMask(bitWidth: bitWidth))))"
    default:
        let mask = hexLiteral(svdBitfieldMask(bitWidth: bitWidth))
        guard defaultValue.isEmpty == false else {
            return """
            let value = (\(parentExpression) >> \(bitOffset)) & \(mask)
            return \(fieldType)(rawValue: value)!
            """
        }

        return """
        let value = (\(parentExpression) >> \(bitOffset)) & \(mask)
        return \(fieldType)(rawValue: value) ?? .\(defaultValue)
        """
    }
}

private func svdBitfieldSetterSource(
    fieldType: String,
    parentExpression: String,
    bitOffset: Int,
    bitWidth: Int,
    writeBehavior: SVDRegisterWriteBehavior
) -> String {
    if writeBehavior == .writeOneToClear {
        return svdDirectBitfieldSetterSource(
            fieldType: fieldType,
            parentExpression: parentExpression,
            bitOffset: bitOffset,
            bitWidth: bitWidth
        )
    }

    switch fieldType {
    case "Bool":
        return "\(parentExpression) = newValue ? (\(parentExpression) | (UInt32(1) << \(bitOffset))) : (\(parentExpression) & ~(UInt32(1) << \(bitOffset)))"
    case "UInt32":
        let mask = hexLiteral(svdBitfieldMask(bitWidth: bitWidth))
        return "\(parentExpression) = (\(parentExpression) & ~(UInt32(\(mask)) << \(bitOffset))) | ((newValue & \(mask)) << \(bitOffset))"
    case "UInt8", "UInt16":
        let mask = hexLiteral(svdBitfieldMask(bitWidth: bitWidth))
        return "\(parentExpression) = (\(parentExpression) & ~(UInt32(\(mask)) << \(bitOffset))) | ((UInt32(newValue) & \(mask)) << \(bitOffset))"
    default:
        let mask = hexLiteral(svdBitfieldMask(bitWidth: bitWidth))
        return "\(parentExpression) = (\(parentExpression) & ~(UInt32(\(mask)) << \(bitOffset))) | ((newValue.rawValue & \(mask)) << \(bitOffset))"
    }
}

private func svdDirectBitfieldSetterSource(
    fieldType: String,
    parentExpression: String,
    bitOffset: Int,
    bitWidth: Int
) -> String {
    let mask = hexLiteral(svdBitfieldMask(bitWidth: bitWidth))

    switch fieldType {
    case "Bool":
        return "if newValue { \(parentExpression) = UInt32(1) << \(bitOffset) }"
    case "UInt32":
        return "if newValue != 0 { \(parentExpression) = (newValue & \(mask)) << \(bitOffset) }"
    case "UInt8", "UInt16":
        return "if newValue != 0 { \(parentExpression) = (UInt32(newValue) & \(mask)) << \(bitOffset) }"
    default:
        return "if newValue.rawValue != 0 { \(parentExpression) = (newValue.rawValue & \(mask)) << \(bitOffset) }"
    }
}
