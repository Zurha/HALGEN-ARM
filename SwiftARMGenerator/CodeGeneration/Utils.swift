//
//  Utils.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 19/02/2026.
//

import Foundation

/// Builds a file header string for Swift source files.
///
/// Creates a formatted header comment block containing the file name,
/// creation date, and copyright information. Optionally generates a
/// lowercase typealias for the file's main type.
///
/// - Parameters:
///   - fileName: The name of the file to include in the header.
///   - generateTypealias: When `true`, includes a typealias declaration
///     at the end of the header. Defaults to `true`.
/// - Returns: A formatted string containing the complete file header.
///
/// - Note: The function uses the current system date to populate
///   the creation date and copyright year. The typealias generation
///   is currently a temporary implementation and should be moved
///   to a different location in a future refactor.
///
/// - Example:
///   ```swift
///   let header = buildFileHeader(for: "MyClass", generateTypealias: true)
///   ```
func buildFileHeader(for fileName: String, generateTypealias: Bool = true) -> String {
    let fullFormatter = DateFormatter()
    fullFormatter.dateFormat = "MM/dd/yyyy"
    let fullDateString = fullFormatter.string(from: Date())
    
    let yearFormatter = DateFormatter()
    yearFormatter.dateFormat = "yyyy"
    let yearString = yearFormatter.string(from: Date())
    
    var typealiasString = ""
    if generateTypealias {
        typealiasString = "public typealias \(fileName.lowercased()) = \(fileName)"
    }
    
    let fileHeader = """
    //===----------------------------------------------------------------------===//
    //
    // \(fileName).swift
    // CoreAVR
    //
    // Created by Swift AVR Generator on \(fullDateString).
    // Copyright © \(yearString) Paul Shelley. All rights reserved.
    //
    //===----------------------------------------------------------------------===//
    
    
    \(typealiasString)
    
    
    """
    // TODO: The typealias should be generated in a different location.
    return fileHeader
}

func indent(_ text: String, by spaces: Int) -> String {
    let prefix = String(repeating: " ", count: spaces)
    return text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in
            line.isEmpty ? "" : prefix + line
        }
        .joined(separator: "\n")
}

func joinDocumentationSections(_ sections: [String]) -> String {
    sections
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
}

func trailingNumericSuffix(in value: String) -> String? {
    let trailingDigits = String(value.reversed().prefix { $0.isNumber }.reversed())
    return trailingDigits.isEmpty ? nil : trailingDigits
}

func peripheralInstanceIndex(for registerGroupName: String) -> String {
    trailingNumericSuffix(in: registerGroupName) ?? "0"
}

func makeDocumentationComment(title: String, body: String = "") -> String {
    var lines = ["/// \(title)"]

    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedBody.isEmpty else {
        return lines.joined(separator: "\n")
    }

    //lines.append("///")
    lines.append(
        contentsOf: trimmedBody
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.isEmpty ? "///" : "/// \(line)"
            }
    )

    return lines.joined(separator: "\n")
}

func makeDocumentationComment(body: String) -> String {
    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedBody.isEmpty else {
        return ""
    }

    return trimmedBody
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in
            line.isEmpty ? "///" : "/// \(line)"
        }
        .joined(separator: "\n")
}

func makeInitialValueRow(from values: [String]?) -> String {
    let normalizedValues = formatInitialValues(values) ?? Array(repeating: "?", count: 8)
    let cells = normalizedValues.map { padString($0, padding: 7) }
    return "\(cells[0])|\(cells[1])|\(cells[2])|\(cells[3])|\(cells[4])|\(cells[5])|\(cells[6])|\(cells[7])"
}

func getVariableName(caption: String) -> String {
    let rawTokens = caption.components(separatedBy: CharacterSet.alphanumerics.inverted)
    let tokens = rawTokens.compactMap { rawToken -> String? in
        let scalars = rawToken.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) == false }
        let cleanedToken = String(String.UnicodeScalarView(scalars))

        guard cleanedToken.isEmpty == false else {
            return nil
        }

        return cleanedToken
    }

    guard let firstToken = tokens.first else {
        return ""
    }

    let leadingToken = firstToken.lowercased()
    let remainingTokens = tokens.dropFirst().map { token in
        let lowercasedToken = token.lowercased()
        return lowercasedToken.prefix(1).uppercased() + lowercasedToken.dropFirst()
    }

    return ([leadingToken] + remainingTokens).joined()
}

/// Adds Padding to strings for documentation. This is intended to be used for centering text in mono-spaced ASCII tables.
/// - Parameter input: String of 7 characters or less.
/// - Returns: A string of 7 characters, if the input string had more than 7 characters it should be unchanged.
func padString(_ input: String, padding: Int) -> String {
    if input.count >= padding {
        return input
    }
    
    let totalPadding = padding - input.count
    let leftPadding = totalPadding / 2
    let rightPadding = totalPadding - leftPadding
    
    return String(repeating: " ", count: leftPadding) + input + String(repeating: " ", count: rightPadding)
}
