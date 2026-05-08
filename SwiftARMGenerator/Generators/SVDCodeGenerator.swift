//
//  SVDCodeGenerator.swift
//  SwiftARMGenerator
//
//  Created by HALGEN on 05/04/2026.
//

import Foundation

struct GeneratedCodeFile {
    let fileName: String
    let content: String
    let subdirectory: String
    let relativePathOverride: String?

    init(
        fileName: String,
        content: String,
        subdirectory: String,
        relativePathOverride: String? = nil
    ) {
        self.fileName = fileName
        self.content = content
        self.subdirectory = subdirectory
        self.relativePathOverride = relativePathOverride
    }

    func relativePath(moduleName: String) -> String {
        if let relativePathOverride {
            return relativePathOverride
        }

        return "Sources/\(moduleName)/\(subdirectory)/\(fileName)"
    }
}

struct GeneratedDeviceOutput {
    let url: URL
    let device: SVDDevice
    let files: [GeneratedCodeFile]

    var moduleName: String {
        device.generatedSwiftModuleName
    }

    func relativePath(for file: GeneratedCodeFile) -> String {
        file.relativePath(moduleName: moduleName)
    }
}

struct SVDCodeGenerator {
    let documentationDirectory: URL?

    func generate(for decodedFile: DecodedSVDFile) -> GeneratedDeviceOutput {
        let pipeline = GenerationPipeline()
        let generatedFiles = pipeline.run(device: decodedFile.device)
        let moduleName = decodedFile.device.generatedSwiftModuleName

        return GeneratedDeviceOutput(
            url: decodedFile.url,
            device: decodedFile.device,
            files: staticSupportFiles(
                moduleName: moduleName,
                includeGPIO: generatedFiles.contains { $0.fileName == "GPIO.swift" }
            ) + generatedFiles
        )
    }
}

private extension SVDCodeGenerator {
    func staticSupportFiles(moduleName: String, includeGPIO: Bool) -> [GeneratedCodeFile] {
        guard includeGPIO else {
            return []
        }

        return [
            makeStaticSupportFile(
                moduleName: moduleName,
                fileName: "Port.swift",
                templatePath: "Sources/CoreARM/CoreARM.swift",
                transform: internalizedSwiftSource
            ),
            makeStaticSupportFile(
                moduleName: moduleName,
                fileName: "DigitalValue.swift",
                templatePath: "Sources/CoreARM/DigitalValue.swift"
            )
        ]
    }

    func makeStaticSupportFile(
        moduleName: String,
        fileName: String,
        templatePath: String,
        transform: (String) -> String = { $0 }
    ) -> GeneratedCodeFile {
        let relativePath = "Sources/\(moduleName)/\(fileName)"
        let content = generatedFileHeader(
            fileName: fileName,
            moduleName: moduleName,
            description: "Static support emitted by Swift ARM Generator."
        ) + transform(staticSupportTemplate(named: templatePath))

        return GeneratedCodeFile(
            fileName: fileName,
            content: content,
            subdirectory: "",
            relativePathOverride: relativePath
        )
    }

    func staticSupportTemplate(named templatePath: String) -> String {
        guard let documentationDirectory else {
            fatalError("Missing documentation directory for static support template '\(templatePath)'")
        }

        let templateURL = documentationDirectory
            .appendingPathComponent("corearm-package", isDirectory: true)
            .appendingRelativeFilePath(templatePath)

        do {
            return try String(contentsOf: templateURL, encoding: .utf8)
        } catch {
            fatalError("Could not read static support template at \(templateURL.path): \(error.localizedDescription)")
        }
    }
}

func generatedFileHeader(fileName: String, moduleName: String, description: String) -> String {
    """
    //
    //  \(fileName)
    //  \(moduleName)
    //
    //  \(description)
    //

    """
}

private func internalizedSwiftSource(_ source: String) -> String {
    source.replacingOccurrences(
        of: #"(?m)^(\s*)public\s+"#,
        with: "$1",
        options: .regularExpression
    )
}

func exportGeneratedOutput(_ generatedOutput: GeneratedDeviceOutput, to outputURL: URL) throws {
    for file in generatedOutput.files {
        let relativePath = generatedOutput.relativePath(for: file)
        let fileURL = outputURL
            .appendingPathComponent(generatedOutput.device.name, isDirectory: true)
            .appendingRelativeFilePath(relativePath)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

func hexLiteral(_ value: UInt64, minimumDigits: Int = 2) -> String {
    let digits = String(value, radix: 16, uppercase: true)
    let paddedDigits = String(repeating: "0", count: max(0, minimumDigits - digits.count)) + digits

    return "0x\(paddedDigits)"
}

func swiftTypeIdentifier(from rawValue: String) -> String {
    let scalars = rawValue.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) || scalar.value == 95 ? Character(scalar) : "_"
    }
    let collapsed = String(scalars).split(separator: "_").map(String.init).joined(separator: "_")

    guard let first = collapsed.unicodeScalars.first else {
        return "_"
    }

    if CharacterSet.decimalDigits.contains(first) {
        return "_\(collapsed)"
    }

    return collapsed
}

extension SVDDevice {
    var generatedSwiftModuleName: String {
        swiftTypeIdentifier(from: series?.nilIfEmpty ?? name)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension URL {
    func appendingRelativeFilePath(_ relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(self) { url, component in
                url.appendingPathComponent(String(component), isDirectory: false)
            }
    }
}
