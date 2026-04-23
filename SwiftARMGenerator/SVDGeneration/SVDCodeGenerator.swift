//
//  SVDCodeGenerator.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 20/04/2026.
//

import Foundation

struct GeneratedSwiftFile {
    let relativePath: String
    let contents: String
}

struct GeneratedDeviceOutput {
    let url: URL
    let device: SVDDevice
    let files: [GeneratedSwiftFile]
}

struct SVDCodeGenerator {
    func generate(for decodedFile: DecodedSVDFile) -> GeneratedDeviceOutput {
        GeneratedDeviceOutput(url: decodedFile.url, device: decodedFile.device, files: [])
    }
}

func exportGeneratedFiles(_ files: [GeneratedSwiftFile], to outputDirectory: URL) throws {
    for file in files {
        let destination = outputDirectory.appendingPathComponent(file.relativePath, isDirectory: false)
        let parentDirectory = destination.deletingLastPathComponent()

        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        try file.contents.write(to: destination, atomically: true, encoding: .utf8)
    }
}
