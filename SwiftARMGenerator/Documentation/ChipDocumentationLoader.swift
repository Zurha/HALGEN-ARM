//
//  ChipDocumentationLoader.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 25/02/2026.
//

import Foundation

struct MissingRegisterLog: Codable {
    let name: String
    let caption: String
    let offset: String
    let suggestedVariableName: String
}

struct MissingBitfieldLog: Codable {
    let name: String
    let caption: String
    let mask: String
    let suggestedVariableName: String
}

struct PeripheralGenerationLog: Codable {
    let name: String
    let missingRegisters: [MissingRegisterLog]
    let missingBitfields: [MissingBitfieldLog]
}

struct ChipGenerationLog: Codable {
    let name: String
    let exported: Bool

    let peripherals: [PeripheralGenerationLog]

    var missingRegisters: [MissingRegisterLog] {
        peripherals.flatMap { $0.missingRegisters }
    }

    var missingBitfields: [MissingBitfieldLog] {
        peripherals.flatMap { $0.missingBitfields }
    }
}

class ChipDocumentationLoader {
    private var chipDocumentation: ChipDocumentation?
    private var generalDocumentation: GeneralDocumentation?
    private var chipName: String = ""
    private let uncategorizedPeripheralName = "Uncategorized"
    private var currentPeripheralName: String?
    private var missingRegistersByPeripheral: [String: [String: MissingRegisterLog]] = [:]
    private var missingBitfieldsByPeripheral: [String: [String: MissingBitfieldLog]] = [:]
    private var registerCache: [String: SupplementalRegisterData] = [:]
    private var bitfieldCache: [String: SupplementalBitfieldData] = [:]
    var directory: URL?
    var inferValueTypes: Bool = false

    var hasMissingSupplementalData: Bool {
        missingRegistersByPeripheral.values.contains { $0.isEmpty == false }
            || missingBitfieldsByPeripheral.values.contains { $0.isEmpty == false }
    }

    var generationLog: ChipGenerationLog {
        let peripheralNames = Set(missingRegistersByPeripheral.keys).union(missingBitfieldsByPeripheral.keys).sorted()
        let peripheralLogs: [PeripheralGenerationLog] = peripheralNames.compactMap { peripheralName in
            let missingRegisters = (missingRegistersByPeripheral[peripheralName] ?? [:]).values.sorted { $0.name < $1.name }
            let missingBitfields = (missingBitfieldsByPeripheral[peripheralName] ?? [:]).values.sorted { $0.name < $1.name }

            guard missingRegisters.isEmpty == false || missingBitfields.isEmpty == false else {
                return nil
            }

            return PeripheralGenerationLog(
                name: peripheralName,
                missingRegisters: missingRegisters,
                missingBitfields: missingBitfields
            )
        }

        return ChipGenerationLog(
            name: chipName,
            exported: peripheralLogs.isEmpty,
            peripherals: peripheralLogs
        )
    }

    func withPeripheralContext<T>(named peripheralName: String, perform: () throws -> T) rethrows -> T {
        let previousPeripheralName = currentPeripheralName
        currentPeripheralName = peripheralName
        defer {
            currentPeripheralName = previousPeripheralName
        }

        return try perform()
    }

    @discardableResult
    func loadGeneral() -> Bool {
        generalDocumentation = nil

        guard let fileURL = directory?.appendingPathComponent("general.json") else {
            return false
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return false
        }

        guard let decodedData = try? JSONDecoder().decode(GeneralDocumentation.self, from: data) else {
            return false
        }

        generalDocumentation = decodedData
        return true
    }

    /// Loads supplemental documentation for a specific chip from a JSON file.
    /// - Parameter chipName: The name of the chip (e.g., "ATSAMD21E18A").
    /// - Returns: `true` if the documentation was successfully loaded, `false` otherwise.
    /// - Note: The JSON file must be named `<chipName>.json` and located in the configured directory.
    @discardableResult
    func load(chipName: String) -> Bool {
        self.chipName = chipName
        chipDocumentation = nil
        currentPeripheralName = nil
        missingRegistersByPeripheral.removeAll()
        missingBitfieldsByPeripheral.removeAll()
        registerCache.removeAll()
        bitfieldCache.removeAll()

        guard let fileURL = directory?.appendingPathComponent("\(chipName).json") else {
            return false
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return false
        }

        guard let decodedData = try? JSONDecoder().decode(ChipDocumentation.self, from: data) else {
            return false
        }

        chipDocumentation = decodedData

        return true
    }

    func supplementalData(for register: SVDRegister) -> SupplementalRegisterData {
        if let cachedData = registerCache[register.name] {
            return cachedData
        }

        let chipDocs = chipDocumentation?.registers[register.name]
        let generalDocs = generalRegister(for: register.name)

        guard chipDocs != nil || generalDocs != nil else {
            let fallbackData = missingSupplementalData(for: register)
            registerCache[register.name] = fallbackData
            return fallbackData
        }

        let fallbackVariableName = getVariableName(caption: register.description ?? register.name)
        let resolvedData = SupplementalRegisterData(
            variableName: preferredVariableName(chipDocs?.variableName, generalDocs?.variableName, fallback: fallbackVariableName),
            valueType: chipDocs?.valueType ?? generalDocs?.valueType ?? "",
            defaultValue: chipDocs?.defaultValue ?? generalDocs?.defaultValue ?? "",
            documentation: formatDocumentation(chipDocs?.documentation),
            access: chipDocs?.access ?? generalDocs?.access ?? register.access ?? "read-write",
            documentationL: formatOptionalDocumentation(chipDocs?.documentationL),
            documentationH: formatOptionalDocumentation(chipDocs?.documentationH),
            initialValues: formatInitialValues(chipDocs?.initialValues),
            initialValuesL: formatInitialValues(chipDocs?.initialValuesL),
            initialValuesH: formatInitialValues(chipDocs?.initialValuesH),
            overrideGeneratedDocumentation: chipDocs?.overrideGeneratedDocumentation ?? false
        )

        registerCache[register.name] = resolvedData
        return resolvedData
    }

    func supplementalData(for field: SVDField) -> SupplementalBitfieldData {
        if let cachedData = bitfieldCache[field.name] {
            return cachedData
        }

        let chipDocs = chipDocumentation?.bitfields[field.name]
        let generalDocs = generalBitfield(for: field.name)

        guard chipDocs != nil || generalDocs != nil else {
            let fallbackData = missingSupplementalData(for: field)
            bitfieldCache[field.name] = fallbackData
            return fallbackData
        }

        let fallbackVariableName = getVariableName(caption: field.description ?? field.name)
        let rawValueType = chipDocs?.valueType ?? generalDocs?.valueType ?? ""
        let inferredValueType = inferValueTypeIfNeeded(rawValueType, field: field)
        let resolvedData = SupplementalBitfieldData(
            variableName: preferredVariableName(chipDocs?.variableName, generalDocs?.variableName, fallback: fallbackVariableName),
            valueType: inferredValueType,
            defaultValue: chipDocs?.defaultValue ?? generalDocs?.defaultValue ?? "",
            documentation: formatDocumentation(chipDocs?.documentation),
            access: accessFromSVD(chipDocs?.access ?? generalDocs?.access ?? field.access ?? "read-write"),
            inline: preferredInline(chipDocs?.inline, generalDocs?.inline),
            splitTargetLSB: chipDocs?.splitTargetLSB,
            overrideGeneratedDocumentation: chipDocs?.overrideGeneratedDocumentation ?? false
        )

        bitfieldCache[field.name] = resolvedData
        return resolvedData
    }

    func boardConfiguration(for device: SVDDevice) -> BoardConfiguration {
        let boardOverrides = chipDocumentation?.board

        return BoardConfiguration(
            ramSize: boardOverrides?.ramSize ?? 0,
            flashSize: boardOverrides?.flashSize ?? 0,
            eepromSize: boardOverrides?.eepromSize,
            baud: boardOverrides?.baud ?? 115200,
            cpuFrequency: boardOverrides?.cpuFrequency ?? 16000000
        )
    }

    private func generalRegister(for alias: String) -> GeneralRegister? {
        generalDocumentation?.registers.first { $0.aliases.contains(alias) }
    }

    private func generalBitfield(for alias: String) -> GeneralBitfield? {
        generalDocumentation?.bitfields.first { $0.aliases.contains(alias) }
    }

    private func preferredVariableName(_ primary: String?, _ secondary: String?, fallback: String) -> String {
        if let primary, primary.isEmpty == false {
            return primary
        }

        if let secondary, secondary.isEmpty == false {
            return secondary
        }

        return fallback
    }

    private func formatOptionalDocumentation(_ paragraphs: [String]?) -> String? {
        guard let paragraphs else {
            return nil
        }

        return formatDocumentation(paragraphs)
    }

    private func preferredInline(_ primary: String?, _ secondary: String?) -> String {
        normalizedNonEmpty(primary) ?? normalizedNonEmpty(secondary) ?? "__always"
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            return nil
        }

        return trimmedValue
    }

    private func activePeripheralName() -> String {
        currentPeripheralName ?? uncategorizedPeripheralName
    }

    private func missingSupplementalData(for register: SVDRegister) -> SupplementalRegisterData {
        let suggestedVariableName = getVariableName(caption: register.description ?? register.name)

        let peripheralName = activePeripheralName()
        var missingRegisters = missingRegistersByPeripheral[peripheralName] ?? [:]

        let offsetString: String = register.addressOffset.map { "0x" + String($0, radix: 16, uppercase: true) } ?? "unknown"

        missingRegisters[register.name] = MissingRegisterLog(
            name: register.name,
            caption: register.description ?? "",
            offset: offsetString,
            suggestedVariableName: suggestedVariableName
        )
        missingRegistersByPeripheral[peripheralName] = missingRegisters

        return SupplementalRegisterData(
            variableName: suggestedVariableName,
            valueType: "",
            defaultValue: "",
            documentation: "",
            access: register.access ?? "read-write",
            isMissing: true
        )
    }

    private func missingSupplementalData(for field: SVDField) -> SupplementalBitfieldData {
        let suggestedVariableName = getVariableName(caption: field.description ?? field.name)

        let peripheralName = activePeripheralName()
        var missingBitfields = missingBitfieldsByPeripheral[peripheralName] ?? [:]

        let maskString = svdFieldMaskHex(field: field)

        missingBitfields[field.name] = MissingBitfieldLog(
            name: field.name,
            caption: field.description ?? "",
            mask: maskString,
            suggestedVariableName: suggestedVariableName
        )
        missingBitfieldsByPeripheral[peripheralName] = missingBitfields

        return SupplementalBitfieldData(
            variableName: suggestedVariableName,
            valueType: "",
            defaultValue: "",
            documentation: "",
            access: accessFromSVD(field.access ?? "read-write")
        )
    }

    private func inferValueTypeIfNeeded(_ valueType: String, field: SVDField) -> String {
        guard inferValueTypes else { return valueType }
        guard valueType.isEmpty else { return valueType }

        let bitWidth = field.bitWidth ?? 0

        if bitWidth == 1 {
            return "Bool"
        }

        if bitWidth <= 8 {
            return "UInt8"
        }

        return valueType
    }

    private func svdFieldMaskHex(field: SVDField) -> String {
        guard let bitOffset = field.bitOffset, let bitWidth = field.bitWidth, bitWidth > 0 else {
            return "0x0"
        }

        let maskValue = ((UInt64(1) << bitWidth) - 1) << bitOffset
        return hexLiteral(maskValue)
    }

    private func accessFromSVD(_ accessString: String) -> Access {
        switch accessString.lowercased() {
        case "read-only", "r":
            return .read
        case "write-only", "w":
            return .write
        default:
            return .readWrite
        }
    }
}

struct BoardConfiguration {
    let ramSize: Int
    let flashSize: Int
    let eepromSize: Int?
    let baud: Int
    let cpuFrequency: Int
}
