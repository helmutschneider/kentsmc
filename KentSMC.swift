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

    static let typeInt8 = SMCString("si8 ")
    static let typeInt32 = SMCString("si32")
    static let typeInt64 = SMCString("si64")
    static let typeUInt8 = SMCString("ui8 ")
    static let typeUInt32 = SMCString("ui32")
    static let typeUInt64 = SMCString("ui64")
    static let typeFloat32 = SMCString("flt ")
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

typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8);

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
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

    init(_ key: SMCString) {
        self.key = key
    }
}

enum SMCValue {
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

    static func fromBytes(_ bytes: SMCBytes, _ info: SMCInfo) -> Self {
        let u32: UInt32 = (UInt32(bytes.0) << 24)
            | (UInt32(bytes.1) << 16)
            | (UInt32(bytes.2) << 8)
            | (UInt32(bytes.3))

        let u64: UInt64 = (UInt64(bytes.0) << 56)
            | (UInt64(bytes.1) << 48)
            | (UInt64(bytes.2) << 40)
            | (UInt64(bytes.3) << 32)
            | (UInt64(bytes.4) << 24)
            | (UInt64(bytes.5) << 16)
            | (UInt64(bytes.6) << 8)
            | (UInt64(bytes.7))

        switch info.type {
            case SMCString.typeInt8:
                let x = Int8(bytes.0)
                return .i8(x)
            case SMCString.typeInt32:
                let x = Int32(u32)
                return .i32(x)
            case SMCString.typeInt64:
                let x = Int64(u64)
                return .i64(x)
            case SMCString.typeUInt8:
                return .u8(bytes.0)
            case SMCString.typeUInt32:
                return .u32(u32)
            case SMCString.typeUInt64:
                return .u64(u64)
            case SMCString.typeFloat32:
                let big = UInt32(bigEndian: u32)
                let f32 = Float(bitPattern: big)
                return .f32(f32)
            default: return .unknown(info.type.toString())
        }
    }
}

enum SMCError : Error {
    case iokit(kern_return_t)
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
        var insize = MemoryLayout<SMCEntry>.size
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

        input.data8 = SMCOperation.kSMCReadKey.rawValue
        input.info.size = outInfo.info.size
        let out = try callStructMethod(&input)
        let v = SMCValue.fromBytes(out.bytes, outInfo.info)

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
        // todo!
    }

    func keys() throws -> [SMCString] {
        let numKeys = try read("#KEY")
        guard case let .u32(numKeys) = numKeys else {
            throw SMCError.string("expected a u32")
        }
        var keys: [SMCString] = []
        for k in 0..<numKeys {
            do {
                let key = try getKeyFromIndex(Int(k))
                keys.append(key)
            } catch {}
        }
        return keys
    }
}

do {
    assert(MemoryLayout<SMCEntry>.size == 80)
    assert(SMCString("#KEY").value == 592135513)
    assert(SMCString("#KEY").toString() == "#KEY")
}

let USAGE: String = """
Usage:
  kentsmc -k [key]               Read a key
  kentsmc -k [key] -w [value]    Write a key
  kentsmc -l                     List all keys
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
        default:
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
        do {
            let value = try conn.read(key.toString())
            print("\(key.toString()) = \(value)")
        } catch {}
        
    }
}

// let keys = try! conn.keys()
