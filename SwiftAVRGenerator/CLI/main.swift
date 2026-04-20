//
//  main.swift
//  SwiftAVRGenerator
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
        let project = candidate.appendingPathComponent("SwiftAVRGenerator.xcodeproj")
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
          --output <path>        Reserved for future code generation output
          --all                  Legacy compatibility flag, currently a no-op
          --infer-value-types    Legacy compatibility flag, currently a no-op
          --help, -h             Show this help message

        Status:
          HALGEN currently decodes CMSIS-SVD input and reports the parsed device structure.
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

func printReport(for decodedFiles: [DecodedSVDFile], inputURL: URL, options: CLIOptions, root: URL) {
    print("Project root : \(root.path)")
    print("Input path   : \(inputURL.path)")

    if let output = options.output {
        print("Output dir   : \(output.path) (reserved for future generation)")
    }

    if options.generateAll || options.inferValueTypes {
        print("Compatibility: accepted legacy AVR flags for transition cleanup")
    }

    print()

    for decoded in decodedFiles {
        let device = decoded.device
        print("Decoded \(decoded.url.lastPathComponent)")
        print("  Device      : \(device.name)")

        if let cpuName = device.cpu?.name {
            print("  CPU         : \(cpuName)")
        }

        print("  Peripherals : \(device.peripheralCount)")
        print("  Interrupts  : \(device.interruptCount)")
        print("  Registers   : \(device.registerCount)")
        print("  Clusters    : \(device.clusterCount)")
        print("  Fields      : \(device.fieldCount)")
        print()
    }

    if decodedFiles.count > 1 {
        let totals = decodedFiles.reduce(into: (peripherals: 0, interrupts: 0, registers: 0, clusters: 0, fields: 0)) { totals, decoded in
            totals.peripherals += decoded.device.peripheralCount
            totals.interrupts += decoded.device.interruptCount
            totals.registers += decoded.device.registerCount
            totals.clusters += decoded.device.clusterCount
            totals.fields += decoded.device.fieldCount
        }

        print("Totals")
        print("  Files       : \(decodedFiles.count)")
        print("  Peripherals : \(totals.peripherals)")
        print("  Interrupts  : \(totals.interrupts)")
        print("  Registers   : \(totals.registers)")
        print("  Clusters    : \(totals.clusters)")
        print("  Fields      : \(totals.fields)")
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
    let svdURLs = try collectSVDURLs(from: inputURL)
    let decodedFiles = try decodeSVDs(at: svdURLs)

    printReport(for: decodedFiles, inputURL: inputURL, options: options, root: root)
} catch let error as CLIError {
    fputs("\(error.message)\n", stderr)
    fputs("Run with --help to see the available options.\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
