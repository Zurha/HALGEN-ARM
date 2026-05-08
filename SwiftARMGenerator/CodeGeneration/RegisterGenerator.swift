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

func buildSVDRegisterGetter(addressExpression: String, offset: UInt64, registerSize: Int) -> String {
    switch registerSize {
    case 8:
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x3) * 8
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        get {
            (_volatileRegisterReadUInt32(\(alignedExpression)) >> \(shift)) & 0x000000FF
        }
        """
    case 16:
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x2) * 8
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        get {
            (_volatileRegisterReadUInt32(\(alignedExpression)) >> \(shift)) & 0x0000FFFF
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
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x3) * 8
        let mask = UInt64(0xFF) << shift
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        set {
            let word = _volatileRegisterReadUInt32(\(alignedExpression))
            _volatileRegisterWriteUInt32(\(alignedExpression), (word & \(hexLiteral(~mask & 0xFFFFFFFF, minimumDigits: 8))) | ((newValue & 0xFF) << \(shift)))
        }
        """
    case 16:
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x2) * 8
        let mask = UInt64(0xFFFF) << shift
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        set {
            let word = _volatileRegisterReadUInt32(\(alignedExpression))
            _volatileRegisterWriteUInt32(\(alignedExpression), (word & \(hexLiteral(~mask & 0xFFFFFFFF, minimumDigits: 8))) | ((newValue & 0xFFFF) << \(shift)))
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
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x3) * 8
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        set {
            _volatileRegisterWriteUInt32(\(alignedExpression), (newValue & 0xFF) << \(shift))
        }
        """
    case 16:
        let alignedOffset = offset & ~0x3
        let shift = (offset & 0x2) * 8
        let alignedExpression = svdRegisterAddressExpression(
            baseName: svdAddressExpressionBase(addressExpression),
            offset: alignedOffset
        )

        return """
        set {
            _volatileRegisterWriteUInt32(\(alignedExpression), (newValue & 0xFFFF) << \(shift))
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
