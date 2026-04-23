//
//  main.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 02/03/2026.
//

import Foundation

struct CLIOptions {
    var input: URL?
    var output: URL?
    var generateAll = false
    var inferValueTypes = false
    var showHelp = false
}

enum CLIError: Error {
    case missingValue(flag: String)
    case unknownArgument(String)
    case inputNotFound(String)
    case noSVDFilesFound(String)

    var message: String {
        switch self {
        case let .missingValue(flag):
            return "error: \(flag) requires a path argument"
        case let .unknownArgument(argument):
            return "error: unknown argument '\(argument)'"
        case let .inputNotFound(path):
            return "error: input path not found at \(path)"
        case let .noSVDFilesFound(path):
            return "error: no .svd files found at \(path)"
        }
    }
}

struct DecodedSVDFile {
    let url: URL
    let device: SVDDevice
}

func projectRoot() -> URL {
    let binary = URL(fileURLWithPath: CommandLine.arguments[0]).standardized
    var candidate = binary.deletingLastPathComponent()

    for _ in 0..<10 {
        let project = candidate.appendingPathComponent("SwiftARMGenerator.xcodeproj")
        if FileManager.default.fileExists(atPath: project.path) {
            return candidate
        }

        candidate = candidate.deletingLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

func printUsage(executableName: String) {
    print(
        """
        Usage: \(executableName) [--input <path>] [--output <path>] [--all] [--infer-value-types]

          --input <path>         SVD file or directory to decode
                                 (default: <project>/SVDs/)
          --output <path>        Output directory for generated Swift files
                                 (default: <project>/Output/)
          --all                  Legacy compatibility flag, currently a no-op
          --infer-value-types    Legacy compatibility flag, currently a no-op
          --help, -h             Show this help message

        Status:
          HALGEN currently decodes CMSIS-SVD input without emitting peripheral Swift files.
        """
    )
}

func parseArguments() throws -> CLIOptions {
    var options = CLIOptions()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--input":
            guard let path = iterator.next() else {
                throw CLIError.missingValue(flag: "--input")
            }

            options.input = URL(fileURLWithPath: path)
        case "--output":
            guard let path = iterator.next() else {
                throw CLIError.missingValue(flag: "--output")
            }

            options.output = URL(fileURLWithPath: path, isDirectory: true)
        case "--all":
            options.generateAll = true
        case "--infer-value-types":
            options.inferValueTypes = true
        case "--help", "-h":
            options.showHelp = true
        default:
            throw CLIError.unknownArgument(argument)
        }
    }

    if let input = options.input, !FileManager.default.fileExists(atPath: input.path) {
        throw CLIError.inputNotFound(input.path)
    }

    return options
}

func collectSVDURLs(from url: URL) throws -> [URL] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        throw CLIError.inputNotFound(url.path)
    }

    if isDirectory.boolValue == false {
        guard url.pathExtension.lowercased() == "svd" else {
            throw CLIError.noSVDFilesFound(url.path)
        }

        return [url]
    }

    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw CLIError.noSVDFilesFound(url.path)
    }

    var svdURLs: [URL] = []

    for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension.lowercased() == "svd" else {
            continue
        }

        svdURLs.append(fileURL)
    }

    svdURLs.sort { $0.path < $1.path }

    guard svdURLs.isEmpty == false else {
        throw CLIError.noSVDFilesFound(url.path)
    }

    return svdURLs
}

func decodeSVDs(at urls: [URL]) throws -> [DecodedSVDFile] {
    let decoder = SVDDecoder()

    return try urls.map { url in
        let device = try decoder.decode(contentsOf: url)
        return DecodedSVDFile(url: url, device: device)
    }
}

func printReport(for generatedOutputs: [GeneratedDeviceOutput], inputURL: URL, outputURL: URL, options: CLIOptions, root: URL) {
    print("Project root : \(root.path)")
    print("Input path   : \(inputURL.path)")
    print("Output dir   : \(outputURL.path)")

    if options.generateAll || options.inferValueTypes {
        print("Compatibility: accepted legacy AVR flags for transition cleanup")
    }

    print()

    for generatedOutput in generatedOutputs {
        let device = generatedOutput.device
        print("Decoded \(generatedOutput.url.lastPathComponent)")
        print("  Device      : \(device.name)")

        if let cpuName = device.cpu?.name {
            print("  CPU         : \(cpuName)")
        }

        print("  Peripherals : \(device.peripheralCount)")
        print("  Interrupts  : \(device.interruptCount)")
        print("  Registers   : \(device.registerCount)")
        print("  Clusters    : \(device.clusterCount)")
        print("  Fields      : \(device.fieldCount)")
        print("  Generated   : \(generatedOutput.files.count)")

        for file in generatedOutput.files {
            print("    \(file.relativePath)")
        }

        print()
    }

    let totals = generatedOutputs.reduce(into: (files: 0, peripherals: 0, interrupts: 0, registers: 0, clusters: 0, fields: 0, generatedFiles: 0)) { totals, generatedOutput in
        totals.files += 1
        totals.peripherals += generatedOutput.device.peripheralCount
        totals.interrupts += generatedOutput.device.interruptCount
        totals.registers += generatedOutput.device.registerCount
        totals.clusters += generatedOutput.device.clusterCount
        totals.fields += generatedOutput.device.fieldCount
        totals.generatedFiles += generatedOutput.files.count
    }

    if generatedOutputs.count > 1 {
        print("Totals")
        print("  Files       : \(totals.files)")
        print("  Peripherals : \(totals.peripherals)")
        print("  Interrupts  : \(totals.interrupts)")
        print("  Registers   : \(totals.registers)")
        print("  Clusters    : \(totals.clusters)")
        print("  Fields      : \(totals.fields)")
        print("  Generated   : \(totals.generatedFiles)")
    } else if let generatedOutput = generatedOutputs.first {
        print("Generated \(generatedOutput.files.count) Swift file(s) for \(generatedOutput.device.name).")
    } else {
        print("No devices were decoded.")
    }
}

func generateOutputs(from decodedFiles: [DecodedSVDFile]) -> [GeneratedDeviceOutput] {
    let generator = SVDCodeGenerator()

    return decodedFiles.map { decodedFile in
        generator.generate(for: decodedFile)
    }
}

func exportOutputs(_ generatedOutputs: [GeneratedDeviceOutput], to outputURL: URL) throws {
    for generatedOutput in generatedOutputs {
        try exportGeneratedFiles(generatedOutput.files, to: outputURL)
    }
}

do {
    let options = try parseArguments()

    if options.showHelp {
        printUsage(executableName: URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent)
        exit(0)
    }

    let root = projectRoot()
    let inputURL = options.input ?? root.appendingPathComponent("SVDs", isDirectory: true)
    let outputURL = options.output ?? root.appendingPathComponent("Output", isDirectory: true)
    let svdURLs = try collectSVDURLs(from: inputURL)
    let decodedFiles = try decodeSVDs(at: svdURLs)
    let generatedOutputs = generateOutputs(from: decodedFiles)

    try exportOutputs(generatedOutputs, to: outputURL)

    printReport(for: generatedOutputs, inputURL: inputURL, outputURL: outputURL, options: options, root: root)
} catch let error as CLIError {
    fputs("\(error.message)\n", stderr)
    fputs("Run with --help to see the available options.\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
