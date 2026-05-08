//
//  GenerationPipeline.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 26/02/2026.
//

import Foundation

struct GenerationPipeline {
    /// Runs all registered peripheral generators for a given device.
    func run(device: SVDDevice, documentation: ChipDocumentationLoader? = nil) -> [GeneratedCodeFile] {
        var files: [GeneratedCodeFile] = []

        for generator in GeneratorRegistry.allGenerators where generator.supports(device: device) {
            if let documentation {
                files.append(contentsOf: generator.generate(device: device, documentation: documentation))
            } else {
                files.append(contentsOf: generator.generate(device: device))
            }
        }

        return files
    }
}
