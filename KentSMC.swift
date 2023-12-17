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

    public static let typeUInt32 = SMCString("ui32")
    public static let typeFloat32 = SMCString("flt ")
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
    case unknown
    case f32(Float)
    case u32(UInt32)

    static func fromBytes(_ bytes: SMCBytes, _ type: SMCString) -> Self {
        switch type {
            case SMCString.typeUInt32:
                var x: UInt32 = (UInt32(bytes.0) << 24)
                    | (UInt32(bytes.1) << 16)
                    | (UInt32(bytes.2) << 8)
                    | (UInt32(bytes.3));
                return .u32(x)
            default: return .unknown
        }
    }
}

enum SMCError : Error {
    case iokit(kern_return_t)
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
        let v = SMCValue.fromBytes(out.bytes, outInfo.info.type)

        return v
    }
    
    func write(_ key: String, value: SMCValue) throws {
        // todo!
    }
}

assert(MemoryLayout<SMCEntry>.size == 80)
assert(SMCString("#KEY").value == 592135513)
assert(SMCString("#KEY").toString() == "#KEY")

let conn = try! SMCConnection()
let numKeys = try! conn.read("#KEY")
print(numKeys)
