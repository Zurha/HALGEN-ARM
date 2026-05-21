    // MARK: - Supporting Types

    /// DMAC trigger source values for CHCTRLB.TRIGSRC.
    enum TriggerSource: UInt32 {
        case disabled = 0
{{triggerCases}}
    }

    /// DMAC channel arbitration level.
    enum PriorityLevel: UInt32 {
        case level0 = 0
        case level1 = 1
        case level2 = 2
        case level3 = 3
    }

    /// DMAC trigger action for CHCTRLB.TRIGACT.
    enum TriggerAction: UInt32 {
        case block = 0
        case beat = 2
        case transaction = 3
    }

    /// Descriptor event output selection for BTCTRL.EVOSEL.
    enum DescriptorEventOutput: UInt32 {
        case disabled = 0
        case block = 1
        case beat = 3
    }

    /// Descriptor block action for BTCTRL.BLOCKACT.
    enum DescriptorBlockAction: UInt32 {
        case noAction = 0
        case interrupt = 1
        case suspend = 2
        case both = 3
    }

    /// DMAC beat size for descriptors.
    enum BeatSize: UInt32 {
        case byte = 0
        case halfWord = 1
        case word = 2
    }

    /// Descriptor step-size target for BTCTRL.STEPSEL.
    enum StepSelection: UInt32 {
        case destination = 0
        case source = 1
    }

    /// Descriptor address increment step size for BTCTRL.STEPSIZE.
    enum StepSize: UInt32 {
        case x1 = 0
        case x2 = 1
        case x4 = 2
        case x8 = 3
        case x16 = 4
        case x32 = 5
        case x64 = 6
        case x128 = 7
    }

    /// DMAC SRAM transfer descriptor.
    ///
    /// Descriptor memory must be aligned to at least 16 bytes before assigning its
    /// address to descriptorBaseAddress or writeBackBaseAddress.
    @_alignment(16)
    struct Descriptor {
        static let byteSize = 16
        static let requiredAlignment = 16

        var blockTransferControl: UInt16
        var blockTransferCount: UInt16
        var sourceAddress: UInt32
        var destinationAddress: UInt32
        var nextDescriptorAddress: UInt32

        init(
            blockTransferControl: UInt16 = 0,
            blockTransferCount: UInt16 = 0,
            sourceAddress: UInt32 = 0,
            destinationAddress: UInt32 = 0,
            nextDescriptorAddress: UInt32 = 0
        ) {
            self.blockTransferControl = blockTransferControl
            self.blockTransferCount = blockTransferCount
            self.sourceAddress = sourceAddress
            self.destinationAddress = destinationAddress
            self.nextDescriptorAddress = nextDescriptorAddress
        }

        @inline(__always)
        static func makeBlockTransferControl(
            valid: Bool = false,
            eventOutput: DescriptorEventOutput = .disabled,
            blockAction: DescriptorBlockAction = .noAction,
            beatSize: BeatSize = .byte,
            sourceIncrement: Bool = false,
            destinationIncrement: Bool = false,
            stepSelection: StepSelection = .destination,
            stepSize: StepSize = .x1
        ) -> UInt16 {
            var value: UInt32 = 0
            if valid { value |= UInt32(1) << 0 }
            value |= (eventOutput.rawValue & 0x03) << 1
            value |= (blockAction.rawValue & 0x03) << 3
            value |= (beatSize.rawValue & 0x03) << 8
            if sourceIncrement { value |= UInt32(1) << 10 }
            if destinationIncrement { value |= UInt32(1) << 11 }
            value |= (stepSelection.rawValue & 0x01) << 12
            value |= (stepSize.rawValue & 0x07) << 13
            return UInt16(value & 0xFFFF)
        }
    }

