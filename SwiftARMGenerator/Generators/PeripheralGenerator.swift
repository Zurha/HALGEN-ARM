//
//  PeripheralGenerator.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 26/02/2026.
//

protocol PeripheralGenerator {
    var name: String { get }
    var logName: String { get }
    var subdirectory: String { get }

    /// Determines whether this peripheral generator can generate code for the specified device.
    func supports(device: SVDDevice) -> Bool

    /// Generates code files for the specified device.
    func generate(device: SVDDevice) -> [GeneratedCodeFile]

    /// Generates code files for the specified device, with access to supplemental documentation.
    func generate(device: SVDDevice, documentation: ChipDocumentationLoader) -> [GeneratedCodeFile]
}

extension PeripheralGenerator {
    var logName: String {
        name
    }

    func generate(device: SVDDevice, documentation: ChipDocumentationLoader) -> [GeneratedCodeFile] {
        generate(device: device)
    }
}
