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
