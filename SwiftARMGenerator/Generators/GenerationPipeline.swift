//
//  GenerationPipeline.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 26/02/2026.
//

struct GenerationPipeline {
    /// Runs all registered peripheral generators for a given device.
    func run(device: SVDDevice) -> [GeneratedCodeFile] {
        var files: [GeneratedCodeFile] = []

        for generator in GeneratorRegistry.allGenerators where generator.supports(device: device) {
            files.append(contentsOf: generator.generate(device: device))
        }

        return files
    }
}
