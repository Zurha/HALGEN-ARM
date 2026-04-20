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

    var message: String {
        switch self {
        case let .missingValue(flag):
            return "error: \(flag) requires a path argument"
        case let .unknownArgument(argument):
            return "error: unknown argument '\(argument)'"
        case let .inputNotFound(path):
            return "error: input path not found at \(path)"
        }
    }
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

          --input <path>         Device description file or directory to process
          --output <path>        Output directory for generated code
                                 (default: <project>/Output/)
          --all                  Legacy compatibility flag, currently a no-op
          --infer-value-types    Legacy compatibility flag, currently a no-op
          --help, -h             Show this help message

        Status:
          The AVR-specific generation flow has been removed.
          This CLI is now a neutral scaffold for future ARM work.
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

func printScaffoldStatus(root: URL, options: CLIOptions) {
    let output = options.output ?? root.appendingPathComponent("Output", isDirectory: true)

    print("Project root : \(root.path)")
    print("Input path   : \(options.input?.path ?? "(not set)")")
    print("Output dir   : \(output.path)")

    if options.generateAll || options.inferValueTypes {
        print("Compatibility: accepted legacy AVR flags for transition cleanup")
    }

    print()
    print("HALGEN is now in scaffold mode.")
    print("No parser or code generation pipeline is configured yet.")
    print("Next step: add an ARM device-description loader and register new generators.")
}

do {
    let options = try parseArguments()

    if options.showHelp {
        printUsage(executableName: URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent)
        exit(0)
    }

    printScaffoldStatus(root: projectRoot(), options: options)
} catch let error as CLIError {
    fputs("\(error.message)\n", stderr)
    fputs("Run with --help to see the available options.\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
