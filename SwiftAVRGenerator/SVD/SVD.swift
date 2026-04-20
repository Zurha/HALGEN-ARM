//
//  SVD.swift
//  SwiftAVRGenerator
//
//  Created by Friso De Backer on 20/04/2026.
//

import Foundation

struct SVDDevice {
    let schemaVersion: String?
    let vendor: String?
    let vendorID: String?
    let name: String
    let series: String?
    let version: String?
    let description: String?
    let licenseText: String?
    let cpu: SVDCPU?
    let headerSystemFilename: String?
    let addressUnitBits: Int?
    let width: Int?
    let size: Int?
    let access: String?
    let resetValue: UInt64?
    let resetMask: UInt64?
    let peripherals: [SVDPeripheral]
}

struct SVDCPU {
    let name: String
    let revision: String?
    let endian: String?
    let mpuPresent: Bool?
    let fpuPresent: Bool?
    let vtorPresent: Bool?
    let nvicPrioBits: Int?
    let vendorSystickConfig: Bool?
}

struct SVDPeripheral {
    let name: String
    let derivedFrom: String?
    let version: String?
    let description: String?
    let groupName: String?
    let prependToName: String?
    let appendToName: String?
    let headerStructName: String?
    let alternatePeripheral: String?
    let baseAddress: UInt64?
    let addressBlocks: [SVDAddressBlock]
    let interrupts: [SVDInterrupt]
    let registers: [SVDRegister]
    let clusters: [SVDCluster]
}

struct SVDAddressBlock {
    let offset: UInt64?
    let size: UInt64?
    let usage: String?
    let protection: String?
}

struct SVDInterrupt {
    let name: String
    let description: String?
    let value: Int?
}

struct SVDCluster {
    let name: String
    let derivedFrom: String?
    let description: String?
    let alternateCluster: String?
    let headerStructName: String?
    let addressOffset: UInt64?
    let dim: Int?
    let dimIncrement: UInt64?
    let dimIndex: String?
    let registers: [SVDRegister]
    let clusters: [SVDCluster]
}

struct SVDRegister {
    let name: String
    let derivedFrom: String?
    let displayName: String?
    let description: String?
    let alternateGroup: String?
    let alternateRegister: String?
    let addressOffset: UInt64?
    let size: Int?
    let access: String?
    let protection: String?
    let resetValue: UInt64?
    let resetMask: UInt64?
    let dim: Int?
    let dimIncrement: UInt64?
    let dimIndex: String?
    let fields: [SVDField]
}

struct SVDField {
    let name: String
    let derivedFrom: String?
    let description: String?
    let bitOffset: Int?
    let bitWidth: Int?
    let lsb: Int?
    let msb: Int?
    let bitRange: String?
    let access: String?
    let modifiedWriteValues: String?
    let readAction: String?
    let enumeratedValues: [SVDEnumeratedValues]
}

struct SVDEnumeratedValues {
    let name: String?
    let usage: String?
    let values: [SVDEnumeratedValue]
}

struct SVDEnumeratedValue {
    let name: String
    let description: String?
    let rawValue: String?
    let value: UInt64?
    let isDefault: Bool?
}

extension SVDDevice {
    var peripheralCount: Int {
        peripherals.count
    }

    var registerCount: Int {
        peripherals.reduce(0) { partialResult, peripheral in
            partialResult + peripheral.registerCount
        }
    }

    var clusterCount: Int {
        peripherals.reduce(0) { partialResult, peripheral in
            partialResult + peripheral.clusterCount
        }
    }

    var fieldCount: Int {
        peripherals.reduce(0) { partialResult, peripheral in
            partialResult + peripheral.fieldCount
        }
    }

    var interruptCount: Int {
        peripherals.reduce(0) { partialResult, peripheral in
            partialResult + peripheral.interrupts.count
        }
    }
}

extension SVDPeripheral {
    var registerCount: Int {
        registers.count + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.registerCount
        }
    }

    var clusterCount: Int {
        clusters.count + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.clusterCount
        }
    }

    var fieldCount: Int {
        let registerFields = registers.reduce(0) { partialResult, register in
            partialResult + register.fieldCount
        }

        return registerFields + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.fieldCount
        }
    }
}

extension SVDCluster {
    var registerCount: Int {
        registers.count + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.registerCount
        }
    }

    var clusterCount: Int {
        clusters.count + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.clusterCount
        }
    }

    var fieldCount: Int {
        let registerFields = registers.reduce(0) { partialResult, register in
            partialResult + register.fieldCount
        }

        return registerFields + clusters.reduce(0) { partialResult, cluster in
            partialResult + cluster.fieldCount
        }
    }
}

extension SVDRegister {
    var fieldCount: Int {
        fields.count
    }
}
