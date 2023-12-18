// 
//  Copyright (c) by Dirk on 15.01.23.
//  Copyright (c) Johan Björk <johanimon@gmail.com>
//

import Foundation

struct SMCVersion { // 6 bytes
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCLimit { // 16 bytes
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpu: UInt32 = 0
    var gpu: UInt32 = 0
    var mem: UInt32 = 0
}

struct SMCInfo { // 9+3=12 bytes
    var size: UInt32 = 0
    var type = SMCString(0)
    var attribute: UInt8 = 0
}

struct SMCString : Equatable {  // 4 bytes
    var value: UInt32 = 0
    
    init(_ value: UInt32) {
        self.value = value
    }

    init(_ str: String) {
        assert(str.count == 4)
        let bytes = Array(str.utf8)
        self.value = (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | (UInt32(bytes[3]))
    }

    func toString() -> String {
        let ch1 = UInt8((self.value >> 24) & 0xff)
        let ch2 = UInt8((self.value >> 16) & 0xff)
        let ch3 = UInt8((self.value >> 8) & 0xff)
        let ch4 = UInt8((self.value) & 0xff)
        let chars = [ch1, ch2, ch3, ch4]
            .map { UnicodeScalar($0) }
            .map { Character($0) }

        return String(chars)
    }
}

struct SMCType {
    private init() {}
    
    static let i8 = SMCString("si8 ")
    static let i16 = SMCString("si16")
    static let i32 = SMCString("si32")
    static let i64 = SMCString("si64")
    static let u8 = SMCString("ui8 ")
    static let u16 = SMCString("ui16")
    static let u32 = SMCString("ui32")
    static let u64 = SMCString("ui64")
    static let f32 = SMCString("flt ")
}

enum SMCOperation : UInt8 {
	case kSMCUserClientOpen  = 0
	case kSMCUserClientClose = 1
	case kSMCHandleYPCEvent  = 2	
    case kSMCReadKey         = 5
	case kSMCWriteKey        = 6
	case kSMCGetKeyCount     = 7
	case kSMCGetKeyFromIndex = 8
	case kSMCGetKeyInfo      = 9
    case kSMCBadOperation    = 0xff
};

struct SMCBytes {
    var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
            = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
}

struct SMCEntry { // 4 + 6(+2) + 16 + 12 + 1 + 1 + 1(+1) + 4 + 32 = 80
    let key: SMCString
    var vers = SMCVersion()
    var limit = SMCLimit()
    var info = SMCInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0

    // 32 bytes. must be statically allocated.
    var bytes = SMCBytes()

    init(_ key: SMCString) {
        self.key = key
    }
}

enum SMCOperationResult : UInt8 {
    case kSMCKeyNotFound = 0x84
}

enum SMCValue : Equatable {
    case i8(Int8)
    case i16(Int16)
    case i32(Int32)
    case i64(Int64)
    case u8(UInt8)
    case u16(UInt16)
    case u32(UInt32)
    case u64(UInt64)
    case f32(Float32)
    case f64(Float64)
    case unknown(String)

    static func fromBytes(_ bytes: SMCBytes, _ type: SMCString) -> Self {
        var bytes = bytes
        let u16: UInt16
        let u32: UInt32
        let u64: UInt64

        do {
            let data = Data(bytes: &bytes, count: 2)
            let big = data.withUnsafeBytes { $0.load(as: UInt16.self) }
            u16 = UInt16(bigEndian: big)
        }

        do {
            let data = Data(bytes: &bytes, count: 4)
            let big = data.withUnsafeBytes { $0.load(as: UInt32.self) }
            u32 = UInt32(bigEndian: big)
        }
        do {
            let data = Data(bytes: &bytes, count: 8)
            let big = data.withUnsafeBytes { $0.load(as: UInt64.self) }
            u64 = UInt64(bigEndian: big)
        }

        switch type {
            case SMCType.i8:
                let x = Int8(bytes.data.0)
                return .i8(x)
            case SMCType.i16:
                let x = Int16(u16)
                return .i16(x)
            case SMCType.i32:
                let x = Int32(u32)
                return .i32(x)
            case SMCType.i64:
                let x = Int64(u64)
                return .i64(x)
            case SMCType.u8:
                return .u8(bytes.data.0)
            case SMCType.u16:
                return .u16(u16)
            case SMCType.u32:
                return .u32(u32)
            case SMCType.u64:
                return .u64(u64)
            case SMCType.f32:
                let f32 = Float(bitPattern: u32.bigEndian)
                return .f32(f32)
            default: return .unknown(type.toString())
        }
    }

    func toBytes() -> SMCBytes {
        var bytes = SMCBytes()
        let buf = UnsafeMutableBufferPointer(start: &bytes, count: 32)

        switch self {
            case let .u8(x): do {
                var big = x.bigEndian;
                let input = Data(bytes: &big, count: 1)
                let _ = input.copyBytes(to: buf)
            }
            case let .u16(x): do {
                var big = x.bigEndian;
                let input = Data(bytes: &big, count: 2)
                let _ = input.copyBytes(to: buf)
            }
            case let .u32(x): do {
                var big = x.bigEndian;
                let input = Data(bytes: &big, count: 4)
                let _ = input.copyBytes(to: buf)
            }
            case let .u64(x): do {
                var big = x.bigEndian;
                let input = Data(bytes: &big, count: 8)
                let _ = input.copyBytes(to: buf)
            }
            case let .f32(x): do {
                var x = x
                let input = Data(bytes: &x, count: 4)
                let _ = input.copyBytes(to: buf)
            }
            default: do {
                print("cowabunga!")
            }
        }

        return bytes
    }
}

enum SMCError : Error {
    case iokit(kern_return_t)
    case keyNotFound(String)
    case string(String)
}

class SMCConnection {
    var handle: io_connect_t = 0
    init() throws {
        var mainport: mach_port_t = 0
        var result = IOMainPort(kIOMainPortDefault, &mainport)
        guard result == kIOReturnSuccess else {
            throw SMCError.iokit(result)
        }
        let serviceDir = IOServiceMatching("AppleSMC")
        let service = IOServiceGetMatchingService(mainport, serviceDir)
        result = IOServiceOpen(service, mach_task_self_ , 0, &handle)
        guard result == kIOReturnSuccess else {
            throw SMCError.iokit(result)
        }
        result = IOObjectRelease(service)
        guard result == kIOReturnSuccess else {
            throw SMCError.iokit(result)
        }
    }
    
    deinit {
        IOServiceClose(handle)
    }

    func callStructMethod(_ input: inout SMCEntry) throws -> SMCEntry {
        var output = SMCEntry(input.key)
        let insize = MemoryLayout<SMCEntry>.size
        var outsize = MemoryLayout<SMCEntry>.size
        let result = IOConnectCallStructMethod(handle, UInt32(SMCOperation.kSMCHandleYPCEvent.rawValue), &input, insize, &output, &outsize)
        guard result == kIOReturnSuccess else {
            throw SMCError.iokit(result)
        }
        return output
    }

    func read(_ key: String) throws -> SMCValue {
        var input = SMCEntry(SMCString(key))
        input.data8 = SMCOperation.kSMCGetKeyInfo.rawValue

        let outInfo = try callStructMethod(&input)
        if outInfo.result == SMCOperationResult.kSMCKeyNotFound.rawValue {
            throw SMCError.keyNotFound(key)
        }

        input.data8 = SMCOperation.kSMCReadKey.rawValue
        input.info.size = outInfo.info.size
        let out = try callStructMethod(&input)
        let v = SMCValue.fromBytes(out.bytes, outInfo.info.type)

        return v
    }

    func getKeyFromIndex(_ index: Int) throws -> SMCString {
        var input = SMCEntry(SMCString(0))
        input.data8 = SMCOperation.kSMCGetKeyFromIndex.rawValue
        input.data32 = UInt32(index)
        let out = try callStructMethod(&input)
        return out.key
    }
    
    func write(_ key: String, value: SMCValue) throws {
        var input = SMCEntry(SMCString(key))
        input.data8 = SMCOperation.kSMCGetKeyInfo.rawValue
        let outInfo = try callStructMethod(&input)
        if outInfo.result == SMCOperationResult.kSMCKeyNotFound.rawValue {
            throw SMCError.keyNotFound(key)
        }
        var write = SMCEntry(SMCString(key))
        write.bytes = value.toBytes()
        write.info.size = outInfo.info.size
        write.data8 = SMCOperation.kSMCWriteKey.rawValue

        let _ = try callStructMethod(&write)

        print("OK: \(key) = \(value)")
    }

    func keys() throws -> [SMCString] {
        let numKeys = try read("#KEY")
        guard case let .u32(numKeys) = numKeys else {
            throw SMCError.string("expected u32")
        }

        var keys: [SMCString] = []
        for k in 0..<numKeys {
            let key = try getKeyFromIndex(Int(k))
            keys.append(key)
        }
        return keys
    }
}

func test() {
    do {
        assert(MemoryLayout<SMCEntry>.size == 80)
        assert(SMCString("#KEY").value == 592135513)
        assert(SMCString("#KEY").toString() == "#KEY")
    }

    do {
        var bytes = SMCBytes()
        bytes.data.0 = 0
        bytes.data.1 = 128
        bytes.data.2 = 137
        bytes.data.3 = 68

        let v = SMCValue.fromBytes(bytes, SMCType.f32)
        assert(v == .f32(1100.0))

        let bytes2 = v.toBytes()
        assert(bytes2.data.0 == 0)
        assert(bytes2.data.1 == 128)
        assert(bytes2.data.2 == 137)
        assert(bytes2.data.3 == 68)
    }

    do {
        var bytes = SMCBytes()
        bytes.data.0 = 0
        bytes.data.1 = 0
        bytes.data.2 = 1
        bytes.data.3 = 1

        let v = SMCValue.fromBytes(bytes, SMCType.u32)
        assert(v == .u32(257))

        let bytes2 = v.toBytes()
        assert(bytes2.data.0 == 0)
        assert(bytes2.data.1 == 0)
        assert(bytes2.data.2 == 1)
        assert(bytes2.data.3 == 1)
    }
}

@main
class App {
    static func printKeyValue(key: String, value: SMCValue) {
        if case .unknown = value {
            return
        }
        if let desc = SMC_KEYS[key] {
            print("\(desc) (\(key))")
            print("  = \(value)\n")
        }
    }

    static func handleError(_ e: Error) {
        print("Error: \(e)")
        print("Did you forget 'sudo'?")
    }

    static func main() throws {
        test()

        let USAGE: String = """
        Usage:
          kentsmc -k [key]               Read a key
          kentsmc -k [key] -w [value]    Write a key
          kentsmc -l                     Dump all keys
          kentsmc -f <filter>            Read keys matching <filter>
          kentsmc --fan-rpm <rpm>        Activates fan manual mode (F%Md) and sets the target rpm (F%Tg)
          kentsmc --fan-auto             Disables fan manual mode
        """;

        var args: [String: String] = [:]
        var index = 1

        while index < CommandLine.argc {
            let arg = CommandLine.arguments[index]
            switch arg {
                case "-k": do {
                    args["-k"] = CommandLine.arguments[index + 1]
                    index += 2
                }
                case "-w": do {
                    args["-w"] = CommandLine.arguments[index + 1]
                    index += 2
                }
                case "-l": do {
                    args["-l"] = ""
                    index += 1
                }
                case "-f": do {
                    args["-f"] = CommandLine.arguments[index + 1]
                    index += 2
                }
                case "--fan-rpm": do {
                    args["--fan-rpm"] = CommandLine.arguments[index + 1]
                    index += 2
                }
                case "--fan-auto": do {
                    args["--fan-auto"] = ""
                    index += 1
                }
                default:
                    print("Unknown argument '\(arg)'")
                    print(USAGE)
                    exit(1)
                    break
            }
        }

        if args.isEmpty {
            print(USAGE)
            exit(1)
        }

        let conn = try! SMCConnection()

        if args.keys.contains("-l") {
            let keys = try conn.keys()
            for key in keys {
                let desc = SMC_KEYS[key.toString()] ?? "<unknown>"
                print("\(key.toString()): \(desc)")
            }
        }

        if args.keys.contains("-k") {
            let key = args["-k"]!

            do {
                let value = try conn.read(key)

                if args.keys.contains("-w") {
                    let toWrite = args["-w"]!
                    let parsed: SMCValue = switch value {
                        case .u8: .u8(UInt8(toWrite)!)
                        case .u16: .u16(UInt16(toWrite)!)
                        case .u32: .u32(UInt32(toWrite)!)
                        case .u64: .u64(UInt64(toWrite)!)
                        case .i8: .i8(Int8(toWrite)!)
                        case .i16: .i16(Int16(toWrite)!)
                        case .i32: .i32(Int32(toWrite)!)
                        case .i64: .i64(Int64(toWrite)!)
                        case .f32: .f32(Float32(toWrite)!)
                        default: .unknown(toWrite)
                    }
                    try conn.write(key, value: parsed)
                } else {
                    printKeyValue(key: key, value: value)
                }
            } catch let e {
                handleError(e)
                exit(1)
            }
        }

        if args.keys.contains("-f") {
            let filter = args["-f"]!
            var keysToRead: [String] = SMC_KEYS
                .filter { $0.value.lowercased().contains(filter) }
                .sorted { a, b in a.value.compare(b.value) == ComparisonResult.orderedAscending }
                .map { $0.key }

            for key in keysToRead {
                do {
                    let value = try conn.read(key)
                    printKeyValue(key: key, value: value)
                } catch SMCError.keyNotFound(_) {
                    // do nothing
                } catch let e {
                    handleError(e)
                    exit(1)
                }
            }
        }

        if args.keys.contains("--fan-rpm") {
            let value = (args["--fan-rpm"]! as NSString).floatValue
            let manualPattern = try Regex(#"F\dMd"#)
            let manualKeys = SMC_KEYS
                .filter { $0.key.contains(manualPattern) }
                .map { $0.key }

            for k in manualKeys {
                do {
                    try conn.write(k, value: .u8(1))
                } catch SMCError.keyNotFound {
                    // do nothing
                } catch let e {
                    handleError(e)
                    exit(1)
                }
            }

            let targetSpeedPattern = try Regex(#"F\dTg"#)
            let targetSpeedKeys = SMC_KEYS
                .filter { $0.key.contains(targetSpeedPattern) }
                .map { $0.key }

            for k in targetSpeedKeys {
                do {
                    try conn.write(k, value: .f32(value))
                } catch SMCError.keyNotFound {
                    // do nothing
                } catch let e {
                    handleError(e)
                    exit(1)
                }
                
            }
        }

        if args.keys.contains("--fan-auto") {
            let pattern = try Regex(#"F\dMd"#)
            let manualKeys = SMC_KEYS
                .filter { $0.key.contains(pattern) }
                .map { $0.key }

            for k in manualKeys {
                do {
                    try conn.write(k, value: .u8(0))
                } catch SMCError.keyNotFound {
                    // do nothing
                } catch let e {
                    handleError(e)
                    exit(1)
                }
            }
        }

        exit(0)
    }
}
