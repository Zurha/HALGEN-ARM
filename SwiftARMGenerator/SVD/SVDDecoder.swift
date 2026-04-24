//
//  SVDDecoder.swift
//  SwiftARMGenerator
//
//  Created by Friso De Backer on 20/04/2026.
//

import Foundation

struct SVDDecoder {
    func decode(contentsOf url: URL) throws -> SVDDevice {
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    func decode(data: Data) throws -> SVDDevice {
        let root = try XMLTreeParser().parse(data: data)
        return try decodeDevice(from: root)
    }

    private func decodeDevice(from node: XMLNode) throws -> SVDDevice {
        guard node.name == "device" else {
            throw SVDDecodingError.invalidRoot(expected: "device", actual: node.name)
        }

        return SVDDevice(
            schemaVersion: node.attributes["schemaVersion"],
            vendor: node.string(named: "vendor"),
            vendorID: node.string(named: "vendorID"),
            name: try node.requiredString(named: "name"),
            series: node.string(named: "series"),
            version: node.string(named: "version"),
            description: node.string(named: "description"),
            licenseText: node.string(named: "licenseText"),
            cpu: try node.child(named: "cpu").map(decodeCPU(from:)),
            headerSystemFilename: node.string(named: "headerSystemFilename"),
            addressUnitBits: node.int(named: "addressUnitBits"),
            width: node.int(named: "width"),
            size: node.int(named: "size"),
            access: node.string(named: "access"),
            resetValue: node.uint64(named: "resetValue"),
            resetMask: node.uint64(named: "resetMask"),
            peripherals: try node.child(named: "peripherals")?.children(named: "peripheral").map(decodePeripheral(from:)) ?? []
        )
    }

    private func decodeCPU(from node: XMLNode) throws -> SVDCPU {
        SVDCPU(
            name: try node.requiredString(named: "name"),
            revision: node.string(named: "revision"),
            endian: node.string(named: "endian"),
            mpuPresent: node.bool(named: "mpuPresent"),
            fpuPresent: node.bool(named: "fpuPresent"),
            vtorPresent: node.bool(named: "vtorPresent"),
            nvicPrioBits: node.int(named: "nvicPrioBits"),
            vendorSystickConfig: node.bool(named: "vendorSystickConfig")
        )
    }

    private func decodePeripheral(from node: XMLNode) throws -> SVDPeripheral {
        let registersNode = node.child(named: "registers")

        return SVDPeripheral(
            name: try node.requiredString(named: "name"),
            derivedFrom: node.attributes["derivedFrom"],
            version: node.string(named: "version"),
            description: node.string(named: "description"),
            groupName: node.string(named: "groupName"),
            prependToName: node.string(named: "prependToName"),
            appendToName: node.string(named: "appendToName"),
            headerStructName: node.string(named: "headerStructName"),
            alternatePeripheral: node.string(named: "alternatePeripheral"),
            baseAddress: node.uint64(named: "baseAddress"),
            addressBlocks: try node.children(named: "addressBlock").map(decodeAddressBlock(from:)),
            interrupts: try node.children(named: "interrupt").map(decodeInterrupt(from:)),
            registers: try registersNode?.children(named: "register").map(decodeRegister(from:)) ?? [],
            clusters: try registersNode?.children(named: "cluster").map(decodeCluster(from:)) ?? []
        )
    }

    private func decodeAddressBlock(from node: XMLNode) throws -> SVDAddressBlock {
        SVDAddressBlock(
            offset: node.uint64(named: "offset"),
            size: node.uint64(named: "size"),
            usage: node.string(named: "usage"),
            protection: node.string(named: "protection")
        )
    }

    private func decodeInterrupt(from node: XMLNode) throws -> SVDInterrupt {
        SVDInterrupt(
            name: try node.requiredString(named: "name"),
            description: node.string(named: "description"),
            value: node.int(named: "value")
        )
    }

    private func decodeCluster(from node: XMLNode) throws -> SVDCluster {
        SVDCluster(
            name: try node.requiredString(named: "name"),
            derivedFrom: node.attributes["derivedFrom"],
            description: node.string(named: "description"),
            alternateCluster: node.string(named: "alternateCluster"),
            headerStructName: node.string(named: "headerStructName"),
            addressOffset: node.uint64(named: "addressOffset"),
            dim: node.int(named: "dim"),
            dimIncrement: node.uint64(named: "dimIncrement"),
            dimIndex: node.string(named: "dimIndex"),
            registers: try node.children(named: "register").map(decodeRegister(from:)),
            clusters: try node.children(named: "cluster").map(decodeCluster(from:))
        )
    }

    private func decodeRegister(from node: XMLNode) throws -> SVDRegister {
        let fieldsNode = node.child(named: "fields")

        return SVDRegister(
            name: try node.requiredString(named: "name"),
            derivedFrom: node.attributes["derivedFrom"],
            displayName: node.string(named: "displayName"),
            description: node.string(named: "description"),
            alternateGroup: node.string(named: "alternateGroup"),
            alternateRegister: node.string(named: "alternateRegister"),
            addressOffset: node.uint64(named: "addressOffset"),
            size: node.int(named: "size"),
            access: node.string(named: "access"),
            protection: node.string(named: "protection"),
            resetValue: node.uint64(named: "resetValue"),
            resetMask: node.uint64(named: "resetMask"),
            dim: node.int(named: "dim"),
            dimIncrement: node.uint64(named: "dimIncrement"),
            dimIndex: node.string(named: "dimIndex"),
            fields: try fieldsNode?.children(named: "field").map(decodeField(from:)) ?? []
        )
    }

    private func decodeField(from node: XMLNode) throws -> SVDField {
        let bitRange = node.string(named: "bitRange")
        let range = bitRange.flatMap(Self.parseBitRange(_:))
        let lsb = node.int(named: "lsb") ?? range?.lsb
        let msb = node.int(named: "msb") ?? range?.msb
        let bitOffset = node.int(named: "bitOffset") ?? lsb
        let bitWidth = node.int(named: "bitWidth") ?? {
            guard let lsb, let msb else {
                return nil
            }

            return msb - lsb + 1
        }()

        return SVDField(
            name: try node.requiredString(named: "name"),
            derivedFrom: node.attributes["derivedFrom"],
            description: node.string(named: "description"),
            bitOffset: bitOffset,
            bitWidth: bitWidth,
            lsb: lsb,
            msb: msb,
            bitRange: bitRange,
            access: node.string(named: "access"),
            modifiedWriteValues: node.string(named: "modifiedWriteValues"),
            readAction: node.string(named: "readAction"),
            enumeratedValues: try node.children(named: "enumeratedValues").map(decodeEnumeratedValues(from:))
        )
    }

    private func decodeEnumeratedValues(from node: XMLNode) throws -> SVDEnumeratedValues {
        SVDEnumeratedValues(
            name: node.string(named: "name"),
            usage: node.string(named: "usage"),
            values: try node.children(named: "enumeratedValue").map(decodeEnumeratedValue(from:))
        )
    }

    private func decodeEnumeratedValue(from node: XMLNode) throws -> SVDEnumeratedValue {
        let rawValue = node.string(named: "value")

        return SVDEnumeratedValue(
            name: try node.requiredString(named: "name"),
            description: node.string(named: "description"),
            rawValue: rawValue,
            value: rawValue.flatMap(Self.parseUInt64(_:)),
            isDefault: node.bool(named: "isDefault")
        )
    }

    private static func parseBitRange(_ rawValue: String) -> (msb: Int, lsb: Int)? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.hasPrefix("["),
              trimmedValue.hasSuffix("]") else {
            return nil
        }

        let content = trimmedValue.dropFirst().dropLast()
        let components = content.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let msb = Int(components[0]),
              let lsb = Int(components[1]) else {
            return nil
        }

        return (msb: msb, lsb: lsb)
    }

    fileprivate static func parseUInt64(_ rawValue: String) -> UInt64? {
        let trimmedValue = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")

        if trimmedValue.hasPrefix("0x") || trimmedValue.hasPrefix("0X") {
            return UInt64(trimmedValue.dropFirst(2), radix: 16)
        }

        if trimmedValue.hasPrefix("0b") || trimmedValue.hasPrefix("0B") {
            return UInt64(trimmedValue.dropFirst(2), radix: 2)
        }

        return UInt64(trimmedValue)
    }
}

private enum SVDDecodingError: LocalizedError {
    case invalidRoot(expected: String, actual: String)
    case missingElement(name: String, parent: String)
    case invalidXML(String)

    var errorDescription: String? {
        switch self {
        case let .invalidRoot(expected, actual):
            return "Expected root element '\(expected)' but found '\(actual)'"
        case let .missingElement(name, parent):
            return "Missing required element '\(name)' in '\(parent)'"
        case let .invalidXML(message):
            return message
        }
    }
}

private struct XMLNode {
    let name: String
    let attributes: [String: String]
    let text: String
    let children: [XMLNode]

    func child(named name: String) -> XMLNode? {
        children.first { $0.name == name }
    }

    func children(named name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }

    func string(named name: String) -> String? {
        child(named: name)?.text.nilIfEmpty
    }

    func requiredString(named name: String) throws -> String {
        guard let value = string(named: name) else {
            throw SVDDecodingError.missingElement(name: name, parent: self.name)
        }

        return value
    }

    func int(named name: String) -> Int? {
        guard let value = string(named: name) else {
            return nil
        }

        if let unsigned = SVDDecoder.parseUInt64(value) {
            return Int(exactly: unsigned)
        }

        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func uint64(named name: String) -> UInt64? {
        guard let value = string(named: name) else {
            return nil
        }

        return SVDDecoder.parseUInt64(value)
    }

    func bool(named name: String) -> Bool? {
        guard let value = string(named: name)?.lowercased() else {
            return nil
        }

        switch value {
        case "true", "1":
            return true
        case "false", "0":
            return false
        default:
            return nil
        }
    }
}

private final class XMLTreeParser: NSObject, XMLParserDelegate {
    private var stack: [XMLNodeBuilder] = []
    private var rootNode: XMLNode?
    private var parserError: Error?

    func parse(data: Data) throws -> XMLNode {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw parserError ?? parser.parserError ?? SVDDecodingError.invalidXML("Unknown XML parsing error")
        }

        guard let rootNode else {
            throw SVDDecodingError.invalidXML("Could not find the root XML element")
        }

        return rootNode
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let node = XMLNodeBuilder(name: qName ?? elementName, attributes: attributeDict)
        stack.append(node)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.appendText(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else {
            return
        }

        stack.last?.appendText(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard let builder = stack.popLast() else {
            return
        }

        let node = builder.build()

        if let parent = stack.last {
            parent.children.append(node)
        } else {
            rootNode = node
        }
    }
}

private final class XMLNodeBuilder {
    let name: String
    let attributes: [String: String]
    var children: [XMLNode] = []
    private var textFragments: [String] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func appendText(_ text: String) {
        textFragments.append(text)
    }

    func build() -> XMLNode {
        XMLNode(
            name: name,
            attributes: attributes,
            text: textFragments.joined().trimmingCharacters(in: .whitespacesAndNewlines),
            children: children
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
