# HALGEN-ARM

> Hardware Abstraction Layer Generator for ARM Cortex-M microcontrollers

HALGEN is a Swift code-generation tool that reads CMSIS-SVD (System View Description) XML files for ARM Cortex-M microcontrollers and produces type-safe Swift register-access code targeting Swift Embedded. The generated code uses `@inline(__always)` memory-mapped I/O with zero-overhead volatile access.

**Currently supports**: Microchip ATSAMD21E18A (Cortex-M0+)

## Quick Start

```bash
# Build and run the generator
./generate.sh
```

This builds the `SwiftARMGeneratorCLI` Xcode target (Release, arm64) and runs it with defaults:
- Input: `./SVDs/` (finds all `.svd` files)
- Output: `./Output/<ChipName>/`

Output is a Swift Package Manager module per chip with generated peripheral code.

## Architecture

### Data Flow

```
SVDs/*.svd  ──[SVDDecoder]──>  SVDDevice (model)
                                      │
docs/<chip>.json  ──[ChipDocumentationLoader]──>  Supplemental docs
docs/general.json                                   │
                                                    ▼
GeneratorRegistry ──[GenerationPipeline]──>  [PeripheralGenerator] × N
                                                    │
                                                    ▼
                                          GeneratedCodeFile[]
                                                    │
                                                    ▼
                                          Output/<Chip>/Sources/<Module>/
```

### Key Components

| Component | File | Role |
|-----------|------|------|
| **CLI** | `CLI/main.swift` | Argument parsing, SVD discovery, decode→generate→export pipeline |
| **SVD Model** | `SVD/SVD.swift` | Pure Swift structs mirroring CMSIS-SVD schema (`SVDDevice`, `SVDPeripheral`, `SVDRegister`, `SVDField`, `SVDCluster`) |
| **SVD Parser** | `SVD/SVDDecoder.swift` | Custom XML parser (no external XML dependency for ARM path) |
| **Code Generator** | `Generators/SVDCodeGenerator.swift` | Top-level orchestrator: loads docs, runs pipeline, adds static support files, exports |
| **Pipeline** | `Generators/GenerationPipeline.swift` | Iterates all registered generators, matches to device via `supports(device:)` |
| **Registry** | `Generators/GeneratorRegistry.swift` | Static list of all active peripheral generators |
| **Peripheral Protocol** | `Generators/PeripheralGenerator.swift` | Protocol: `name`, `subdirectory`, `supports(device:)`, `generate(device:documentation:)` |
| **Register Generator** | `CodeGeneration/RegisterGenerator.swift` | Shared helper: generates Swift computed properties for registers (8/16/32-bit, volatile R/W, write-one-to-clear) |
| **Bitfield Generator** | `CodeGeneration/BitfieldGenerator.swift` | Shared helper: generates bitfield sub-accessors (Bool/UInt32/UInt8/UInt16, typed enums) |
| **Documentation Loader** | `Documentation/ChipDocumentationLoader.swift` | Loads `docs/<chip>.json` + `docs/general.json`, resolves scoped supplemental data for registers/bitfields/enum values. Tracks missing data for quality reporting. |
| **Boilerplate** | `Documentation/BoilerplateTemplate.swift` | Loads template `.swift` files from `docs/boilerplate/` with `{{placeholder}}` substitution |
| **Code Formatter** | `CodeGeneration/Linter/` | SwiftSyntax-based formatting of generated output |
| **Utils** | `CodeGeneration/Utils.swift` | Naming conventions (camelCase conversion, reserved word handling), documentation comment builders |

### Peripheral Generators

Each peripheral gets its own generator struct conforming to `PeripheralGenerator`:

| Generator | File | Detects | Output |
|-----------|------|---------|--------|
| GPIO | `Generators/Peripherals/GPIO.swift` | `PORT` peripheral | Port groups (PORTA, PORTB), register properties, DigitalPin typealiases |
| SERCOM | `Generators/Peripherals/SERCOM.swift` | SERCOM instances | One file per instance (USART/I2C/SPI modules from cluster-based register layout) |
| GCLK | `Generators/Peripherals/GenericClockController.swift` | `GCLK` peripheral | Clock generator config, source/generator/channel ID enums |
| PM | `Generators/Peripherals/PowerManager.swift` | `PM` peripheral | Sleep modes, clock prescalers, peripheral clock mask registers |
| DMAC | `Generators/Peripherals/DMAC.swift` | `DMAC` peripheral | DMA controller registers, SRAM descriptor layout types |

## Adding a New Peripheral Generator

1. **Create the generator** in `SwiftARMGenerator/Generators/Peripherals/`. Implement the `PeripheralGenerator` protocol:
   ```swift
   struct MyNewGenerator: PeripheralGenerator {
       let name: String = "MyNew"
       let subdirectory: String = "module"

       func supports(device: SVDDevice) -> Bool {
           device.peripherals.contains { $0.name == "MY_NEW" }
       }

       func generate(device: SVDDevice, documentation: ChipDocumentationLoader) -> [GeneratedCodeFile] {
           guard let peripheral = device.peripherals.first(where: { $0.name == "MY_NEW" }) else {
               return []
           }
           // Build code using shared helpers:
           //   - generateSVDRegister() for register properties
           //   - ChipDocumentationLoader.supplementalData(for:) for docs
           //   - generatedFileHeader() for file preamble
           // Return [GeneratedCodeFile]
       }
   }
   ```

2. **Register it** in `Generators/GeneratorRegistry.swift`:
   ```swift
   static let allGenerators: [PeripheralGenerator] = [
       GPIOGenerator(),
       GenericClockControllerGenerator(),
       PowerManagerGenerator(),
       SERCOMGenerator(),
       DMACGenerator(),
       MyNewGenerator()  // <-- add here
   ]
   ```

3. **Add supplemental documentation** (optional but recommended):
   - Add register/bitfield overrides to `docs/<chip>.json`
   - Add shared patterns to `docs/general.json`
   - Keys support scoped resolution: `PERIPHERAL.register`, `register.bitfield`, `PERIPHERAL.register.bitfield`

## Supplemental Documentation System

Two JSON files feed the `ChipDocumentationLoader` to override raw SVD descriptions:

### `docs/<chip>.json` — Chip-specific overrides
```json
{
  "chip": "ATSAMD21E18A",
  "datasheet": "https://...",
  "board": { "ramSize": 32768, "flashSize": 262144, "cpuFrequency": 48000000 },
  "registers": {
    "GCLK.CLKCTRL": {
      "variableName": "clockControl",
      "documentation": ["Controls clock generator selection and output."],
      "access": "read-write"
    }
  },
  "bitfields": {
    "GCLK.CLKCTRL.GEN": {
      "variableName": "generatorID",
      "valueType": "UInt8",
      "documentation": ["Selects which clock generator drives this channel."]
    }
  },
  "enumValues": {
    "GCLK.CLKCTRL.GEN": {
      "GCLKGEN0": { "caseName": "generator0", "documentation": ["Generator 0"] }
    }
  }
}
```

### `docs/general.json` — Cross-chip reusable patterns
```json
{
  "registers": [
    { "aliases": ["CTRLA"], "variableName": "controlA", "valueType": "UInt32", "access": "read-write" }
  ],
  "bitfields": []
}
```

**Key resolution order**: Scoped keys are checked from most specific to least specific:
- `PERIPHERAL.register` → `register` → (chip docs then general docs aliases)
- `PERIPHERAL.register.bitfield` → `register.bitfield` → `bitfield`

If no supplemental data is found, the system auto-generates a camelCase name from the SVD field name and logs it as "missing" in the generation report.

## Code Generation Patterns

### Register properties
Generated as computed static properties using `@inline(__always)`:
```swift
@inline(__always)
static var controlA: UInt32 {
    get {
        _volatileRegisterReadUInt32(baseAddress + 0x00)
    }
    set {
        _volatileRegisterWriteUInt32(baseAddress + 0x00, newValue)
    }
}
```

8-bit and 16-bit registers use aligned 32-bit reads with masking and shifting.

### Bitfield accessors
Nested computed properties on the register struct (after the register property):
```swift
@inline(__always)
static var enable: Bool {
    get { (controlA & (UInt32(1) << 0)) != 0 }
    set { controlA = newValue ? (controlA | (UInt32(1) << 0)) : (controlA & ~(UInt32(1) << 0))) }
}
```

### Static support files
The generator copies `docs/corearm-package/Sources/CoreARM/` files into the output module:
- `Port.swift` — `AtomicPort` protocol, `Bit<N>` types, `DigitalPin`, `PartialPort`
- `DigitalValue.swift` — `DigitalValue` (high/low abstraction)

### Boilerplate templates
Files in `docs/boilerplate/` use `{{placeholder}}` syntax for substitution (e.g., DMAC enum cases).

## Build & Run Details

### Build (Xcode)
```bash
xcodebuild -project SwiftARMGenerator.xcodeproj \
  -scheme SwiftARMGeneratorCLI \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath .build
```

### Run directly
```bash
.build/Build/Products/Release/SwiftARMGeneratorCLI \
  --input SVDs/ATSAMD21E18A.svd \
  --output Output/
```

### CLI Flags
| Flag | Description |
|------|-------------|
| `--input <path>` | SVD file or directory (default: `./SVDs/`) |
| `--output <path>` | Output directory (default: `./Output/`) |
| `--help`, `-h` | Show usage |

## Dependencies

Resolved via Swift Package Manager inside Xcode:
- **SwiftSyntax** + **SwiftParser** — code formatting/linting of generated Swift output

## Key Conventions

1. **Protocol-driven generation**: Each peripheral is a separate `PeripheralGenerator` struct. Adding one = new file + registry entry.
2. **Named documentation keys**: Register/bitfield overrides use dot-separated scoped keys. The loader resolves most-specific → least-specific.
3. **Volatile memory access**: Generated code calls helper functions (`_volatileRegisterReadUInt32`/`_volatileRegisterWriteUInt32`) that map to raw pointer access with volatile semantics.
4. **All generated accessors are `@inline(__always)` and `static`** — no struct instantiation needed.
5. **Legacy AVR code** exists in `GenerationApi.swift` (ATDF decoding, export) but is inactive for the ARM path.

## Project State (May 2026)

- **5 peripheral generators** complete: GPIO, SERCOM, GCLK, PM, DMAC
- **1 chip supported**: ATSAMD21E18A (SAMD21 series)
- **Active development**: DMAC just added, register access pattern recently refactored
- **No automated tests** — validation via SwiftSyntax linting of generated output + manual review

## Directory Reference

```
SwiftARMGenerator/
├── CLI/main.swift                 Entry point
├── SVD/
│   ├── SVD.swift                  CMSIS-SVD data model
│   └── SVDDecoder.swift           Custom XML → SVD parser
├── Generators/
│   ├── SVDCodeGenerator.swift     Orchestrator (docs + pipeline + export)
│   ├── GenerationPipeline.swift   Runs all matching peripheral generators
│   ├── GeneratorRegistry.swift    Static list of active generators
│   ├── PeripheralGenerator.swift  Protocol definition
│   ├── GenerationApi.swift        Legacy AVR code (inactive for ARM)
│   └── Peripherals/
│       ├── GPIO.swift
│       ├── SERCOM.swift
│       ├── GenericClockController.swift
│       ├── PowerManager.swift
│       └── DMAC.swift
├── CodeGeneration/
│   ├── RegisterGenerator.swift    Register property codegen
│   ├── BitfieldGenerator.swift    Bitfield accessor codegen
│   ├── SupplementalData.swift     Data types for doc overrides
│   ├── Utils.swift                Naming, documentation helpers
│   └── Linter/                    SwiftSyntax formatting
├── Documentation/
│   ├── ChipDocumentation.swift    Codable models for JSON docs
│   ├── ChipDocumentationLoader.swift  Loader + resolution + missing-data tracking
│   ├── GeneralDocumentation.swift Model for shared patterns
│   └── BoilerplateTemplate.swift  .swift template loading + substitution
└── Extensions/
    └── Extensions.swift           String helpers (hex, validation)

docs/
├── ATSAMD21E18A.json              Chip-specific supplemental data
├── general.json                   Cross-chip reusable patterns
├── boilerplate/                   .swift templates with {{substitution}}
└── corearm-package/               Static support files copied to output module
    └── Sources/CoreARM/
        ├── CoreARM.swift          Port, Bit, DigitalPin protocols
        ├── DigitalValue.swift
        └── Utilities.swift

SVDs/
└── ATSAMD21E18A.svd               Input CMSIS-SVD XML
```
