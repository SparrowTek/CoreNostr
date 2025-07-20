import Foundation

/// NIP-19: bech32-encoded entities
/// https://github.com/nostr-protocol/nips/blob/master/19.md
public enum Bech32Entity: Sendable {
    case npub(String)  // Public key
    case nsec(String)  // Private key
    case note(String)  // Event ID
    case nprofile(NProfile)  // Public key + relays
    case nevent(NEvent)  // Event ID + relays + author
    case nrelay(String)  // Relay URL
    case naddr(NAddr)  // Replaceable event coordinate
}

public struct NProfile: Sendable {
    public let pubkey: String
    public let relays: [String]
    
    public init(pubkey: String, relays: [String] = []) throws {
        try Validation.validatePublicKey(pubkey)
        for relay in relays {
            try Validation.validateRelayURL(relay)
        }
        self.pubkey = pubkey
        self.relays = relays
    }
}

public struct NEvent: Sendable {
    public let eventId: String
    public let relays: [String]?
    public let author: String?
    public let kind: Int?
    
    public init(eventId: String, relays: [String]? = nil, author: String? = nil, kind: Int? = nil) throws {
        try Validation.validateEventId(eventId)
        if let author = author {
            try Validation.validatePublicKey(author)
        }
        if let relays = relays {
            for relay in relays {
                try Validation.validateRelayURL(relay)
            }
        }
        self.eventId = eventId
        self.relays = relays
        self.author = author
        self.kind = kind
    }
}

public struct NAddr: Sendable {
    public let identifier: String
    public let pubkey: String
    public let kind: Int
    public let relays: [String]?
    
    public init(identifier: String, pubkey: String, kind: Int, relays: [String]? = nil) throws {
        try Validation.validatePublicKey(pubkey)
        if let relays = relays {
            for relay in relays {
                try Validation.validateRelayURL(relay)
            }
        }
        self.identifier = identifier
        self.pubkey = pubkey
        self.kind = kind
        self.relays = relays
    }
}

/// Bech32 encoding/decoding for Nostr entities
public struct Bech32 {
    private static let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    private static let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    
    /// Human-readable part (HRP) for each entity type
    public enum HRP: String {
        case npub = "npub"
        case nsec = "nsec"
        case note = "note"
        case nprofile = "nprofile"
        case nevent = "nevent"
        case nrelay = "nrelay"
        case naddr = "naddr"
    }
    
    /// Encode data with HRP
    public static func encode(hrp: String, data: Data) throws -> String {
        let values = try convertBits(from: Array(data), fromBits: 8, toBits: 5, pad: true)
        let checksum = createChecksum(hrp: hrp, values: values)
        let combined = values + checksum
        
        let encoded = combined.map { charset[charset.index(charset.startIndex, offsetBy: Int($0))] }
        return hrp + "1" + String(encoded)
    }
    
    /// Decode bech32 string
    public static func decode(_ string: String) throws -> (hrp: String, data: Data) {
        guard let separatorIndex = string.lastIndex(of: "1") else {
            throw NostrError.invalidBech32("No separator found")
        }
        
        let hrp = String(string[..<separatorIndex]).lowercased()
        let dataString = String(string[string.index(after: separatorIndex)...]).lowercased()
        
        // Verify charset
        for char in dataString {
            guard charset.contains(char) else {
                throw NostrError.invalidBech32("Invalid character: \(char)")
            }
        }
        
        // Convert to values
        let values = try dataString.map { char -> UInt8 in
            guard let index = charset.firstIndex(of: char) else {
                throw NostrError.invalidBech32("Invalid character")
            }
            return UInt8(charset.distance(from: charset.startIndex, to: index))
        }
        
        // Verify checksum
        guard values.count >= 6 else {
            throw NostrError.invalidBech32("Data too short")
        }
        
        let checksumLength = 6
        let dataValues = Array(values.dropLast(checksumLength))
        let checksum = Array(values.suffix(checksumLength))
        let expectedChecksum = createChecksum(hrp: hrp, values: dataValues)
        
        guard checksum == expectedChecksum else {
            throw NostrError.invalidBech32("Invalid checksum")
        }
        
        // Convert back to bytes
        let bytes = try convertBits(from: dataValues, fromBits: 5, toBits: 8, pad: false)
        return (hrp, Data(bytes))
    }
    
    /// Polymod calculation for checksum
    private static func polymod(_ values: [UInt8]) -> UInt32 {
        var chk: UInt32 = 1
        for value in values {
            let b = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ UInt32(value)
            for i in 0..<5 {
                chk ^= ((b >> i) & 1) != 0 ? generator[i] : 0
            }
        }
        return chk
    }
    
    /// Create checksum for HRP and data
    private static func createChecksum(hrp: String, values: [UInt8]) -> [UInt8] {
        var enc = hrpExpand(hrp)
        enc.append(contentsOf: values)
        enc.append(contentsOf: [0, 0, 0, 0, 0, 0])
        let mod = polymod(enc) ^ 1
        var ret: [UInt8] = []
        for i in 0..<6 {
            ret.append(UInt8((mod >> (5 * (5 - i))) & 31))
        }
        return ret
    }
    
    /// Expand HRP for checksum calculation
    private static func hrpExpand(_ hrp: String) -> [UInt8] {
        var ret: [UInt8] = []
        for char in hrp {
            let value = char.asciiValue ?? 0
            ret.append(value >> 5)
        }
        ret.append(0)
        for char in hrp {
            let value = char.asciiValue ?? 0
            ret.append(value & 31)
        }
        return ret
    }
    
    /// Convert between bit groups
    private static func convertBits(from: [UInt8], fromBits: Int, toBits: Int, pad: Bool) throws -> [UInt8] {
        var acc = 0
        var bits = 0
        var ret: [UInt8] = []
        let maxv = (1 << toBits) - 1
        let maxAcc = (1 << (fromBits + toBits - 1)) - 1
        
        for value in from {
            if (value >> fromBits) != 0 {
                throw NostrError.invalidBech32("Invalid data for conversion")
            }
            acc = ((acc << fromBits) | Int(value)) & maxAcc
            bits += fromBits
            while bits >= toBits {
                bits -= toBits
                ret.append(UInt8((acc >> bits) & maxv))
            }
        }
        
        if pad {
            if bits > 0 {
                ret.append(UInt8((acc << (toBits - bits)) & maxv))
            }
        } else if bits >= fromBits {
            throw NostrError.invalidBech32("Invalid padding")
        } else if ((acc << (toBits - bits)) & maxv) != 0 {
            throw NostrError.invalidBech32("Invalid padding")
        }
        
        return ret
    }
}

/// Extension to encode/decode Nostr entities
public extension Bech32Entity {
    /// Encode entity to bech32 string
    var encoded: String {
        get throws {
            switch self {
            case .npub(let pubkey):
                guard let data = Data(hex: pubkey) else {
                    throw NostrError.invalidBech32("Invalid public key hex")
                }
                return try Bech32.encode(hrp: Bech32.HRP.npub.rawValue, data: data)
                
            case .nsec(let privkey):
                guard let data = Data(hex: privkey) else {
                    throw NostrError.invalidBech32("Invalid private key hex")
                }
                return try Bech32.encode(hrp: Bech32.HRP.nsec.rawValue, data: data)
                
            case .note(let eventId):
                guard let data = Data(hex: eventId) else {
                    throw NostrError.invalidBech32("Invalid event ID hex")
                }
                return try Bech32.encode(hrp: Bech32.HRP.note.rawValue, data: data)
                
            case .nprofile(let profile):
                let tlv = try encodeTLV(profile: profile)
                return try Bech32.encode(hrp: Bech32.HRP.nprofile.rawValue, data: tlv)
                
            case .nevent(let event):
                let tlv = try encodeTLV(event: event)
                return try Bech32.encode(hrp: Bech32.HRP.nevent.rawValue, data: tlv)
                
            case .nrelay(let url):
                let data = Data(url.utf8)
                return try Bech32.encode(hrp: Bech32.HRP.nrelay.rawValue, data: data)
                
            case .naddr(let addr):
                let tlv = try encodeTLV(addr: addr)
                return try Bech32.encode(hrp: Bech32.HRP.naddr.rawValue, data: tlv)
            }
        }
    }
    
    /// Decode from bech32 string
    init(from string: String) throws {
        let (hrp, data) = try Bech32.decode(string)
        
        switch hrp {
        case Bech32.HRP.npub.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32("Invalid public key length")
            }
            self = .npub(data.hex)
            
        case Bech32.HRP.nsec.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32("Invalid private key length")
            }
            self = .nsec(data.hex)
            
        case Bech32.HRP.note.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32("Invalid event ID length")
            }
            self = .note(data.hex)
            
        case Bech32.HRP.nprofile.rawValue:
            let profile = try Self.decodeTLVProfile(from: data)
            self = .nprofile(profile)
            
        case Bech32.HRP.nevent.rawValue:
            let event = try Self.decodeTLVEvent(from: data)
            self = .nevent(event)
            
        case Bech32.HRP.nrelay.rawValue:
            guard let url = String(data: data, encoding: .utf8) else {
                throw NostrError.invalidBech32("Invalid relay URL")
            }
            self = .nrelay(url)
            
        case Bech32.HRP.naddr.rawValue:
            let addr = try Self.decodeTLVAddr(from: data)
            self = .naddr(addr)
            
        default:
            throw NostrError.invalidBech32("Unknown HRP: \(hrp)")
        }
    }
    
    /// TLV type definitions
    private enum TLVType: UInt8 {
        case special = 0
        case relay = 1
        case author = 2
        case kind = 3
    }
    
    /// Encode TLV for nprofile
    private func encodeTLV(profile: NProfile) throws -> Data {
        var result = Data()
        
        // Add pubkey (special = 0)
        result.append(TLVType.special.rawValue)
        result.append(32) // length
        guard let pubkeyData = Data(hex: profile.pubkey) else {
            throw NostrError.invalidBech32("Invalid public key hex")
        }
        result.append(pubkeyData)
        
        // Add relays
        for relay in profile.relays {
            let relayData = Data(relay.utf8)
            result.append(TLVType.relay.rawValue)
            result.append(UInt8(relayData.count))
            result.append(relayData)
        }
        
        return result
    }
    
    /// Encode TLV for nevent
    private func encodeTLV(event: NEvent) throws -> Data {
        var result = Data()
        
        // Add event ID (special = 0)
        result.append(TLVType.special.rawValue)
        result.append(32) // length
        guard let eventIdData = Data(hex: event.eventId) else {
            throw NostrError.invalidBech32("Invalid event ID hex")
        }
        result.append(eventIdData)
        
        // Add relays
        if let relays = event.relays {
            for relay in relays {
                let relayData = Data(relay.utf8)
                result.append(TLVType.relay.rawValue)
                result.append(UInt8(relayData.count))
                result.append(relayData)
            }
        }
        
        // Add author
        if let author = event.author {
            result.append(TLVType.author.rawValue)
            result.append(32) // length
            guard let authorData = Data(hex: author) else {
                throw NostrError.invalidBech32("Invalid author hex")
            }
            result.append(authorData)
        }
        
        // Add kind
        if let kind = event.kind {
            var kindBytes = withUnsafeBytes(of: UInt32(kind).bigEndian) { Data($0) }
            // Remove leading zeros
            while kindBytes.count > 1 && kindBytes.first == 0 {
                kindBytes = kindBytes.dropFirst()
            }
            result.append(TLVType.kind.rawValue)
            result.append(UInt8(kindBytes.count))
            result.append(kindBytes)
        }
        
        return result
    }
    
    /// Encode TLV for naddr
    private func encodeTLV(addr: NAddr) throws -> Data {
        var result = Data()
        
        // Add identifier (special = 0)
        let idData = Data(addr.identifier.utf8)
        result.append(TLVType.special.rawValue)
        result.append(UInt8(idData.count))
        result.append(idData)
        
        // Add relays
        if let relays = addr.relays {
            for relay in relays {
                let relayData = Data(relay.utf8)
                result.append(TLVType.relay.rawValue)
                result.append(UInt8(relayData.count))
                result.append(relayData)
            }
        }
        
        // Add author
        result.append(TLVType.author.rawValue)
        result.append(32) // length
        guard let pubkeyData = Data(hex: addr.pubkey) else {
            throw NostrError.invalidBech32("Invalid public key hex")
        }
        result.append(pubkeyData)
        
        // Add kind
        var kindBytes = withUnsafeBytes(of: UInt32(addr.kind).bigEndian) { Data($0) }
        // Remove leading zeros
        while kindBytes.count > 1 && kindBytes[0] == 0 {
            kindBytes = kindBytes.dropFirst()
        }
        result.append(TLVType.kind.rawValue)
        result.append(UInt8(kindBytes.count))
        result.append(kindBytes)
        
        return result
    }
    
    /// Decode TLV for nprofile
    private static func decodeTLVProfile(from data: Data) throws -> NProfile {
        var pubkey: String?
        var relays: [String] = []
        
        var index = data.startIndex
        while index < data.endIndex {
            guard index + 2 <= data.endIndex else { break }
            
            guard index < data.count, index + 1 < data.count else { break }
            let type = data[index]
            let lengthByte = data[index + 1]
            let length = Int(lengthByte)
            index += 2
            
            guard index + length <= data.endIndex else {
                throw NostrError.invalidBech32("Invalid TLV data")
            }
            
            let value = data[index..<index + length]
            
            switch TLVType(rawValue: type) {
            case .special:
                if length == 32 {
                    pubkey = value.hex
                }
            case .relay:
                if let relay = String(data: value, encoding: .utf8) {
                    relays.append(relay)
                }
            default:
                break
            }
            
            index += length
        }
        
        guard let pubkey = pubkey else {
            throw NostrError.invalidBech32("Missing pubkey in nprofile")
        }
        
        return try NProfile(pubkey: pubkey, relays: relays)
    }
    
    /// Decode TLV for nevent
    private static func decodeTLVEvent(from data: Data) throws -> NEvent {
        var eventId: String?
        var relays: [String] = []
        var author: String?
        var kind: Int?
        
        var index = data.startIndex
        while index < data.endIndex {
            guard index + 2 <= data.endIndex else { break }
            
            guard index < data.count, index + 1 < data.count else { break }
            let type = data[index]
            let lengthByte = data[index + 1]
            let length = Int(lengthByte)
            index += 2
            
            guard index + length <= data.endIndex else {
                throw NostrError.invalidBech32("Invalid TLV data")
            }
            
            let value = data[index..<index + length]
            
            switch TLVType(rawValue: type) {
            case .special:
                if length == 32 {
                    eventId = value.hex
                }
            case .relay:
                if let relay = String(data: value, encoding: .utf8) {
                    relays.append(relay)
                }
            case .author:
                if length == 32 {
                    author = value.hex
                }
            case .kind:
                if length <= 4 {
                    var kindValue: UInt32 = 0
                    for byte in value {
                        kindValue = (kindValue << 8) | UInt32(byte)
                    }
                    kind = Int(kindValue)
                }
            default:
                break
            }
            
            index += length
        }
        
        guard let eventId = eventId else {
            throw NostrError.invalidBech32("Missing event ID in nevent")
        }
        
        return try NEvent(eventId: eventId, relays: relays.isEmpty ? nil : relays, author: author, kind: kind)
    }
    
    /// Decode TLV for naddr
    private static func decodeTLVAddr(from data: Data) throws -> NAddr {
        var identifier: String?
        var relays: [String] = []
        var pubkey: String?
        var kind: Int?
        
        var index = data.startIndex
        while index < data.endIndex {
            guard index + 2 <= data.endIndex else { break }
            
            guard index < data.count, index + 1 < data.count else { break }
            let type = data[index]
            let lengthByte = data[index + 1]
            let length = Int(lengthByte)
            index += 2
            
            guard index + length <= data.endIndex else {
                throw NostrError.invalidBech32("Invalid TLV data")
            }
            
            let value = data[index..<index + length]
            
            switch TLVType(rawValue: type) {
            case .special:
                if let id = String(data: value, encoding: .utf8) {
                    identifier = id
                }
            case .relay:
                if let relay = String(data: value, encoding: .utf8) {
                    relays.append(relay)
                }
            case .author:
                if length == 32 {
                    pubkey = value.hex
                }
            case .kind:
                if length <= 4 {
                    var kindValue: UInt32 = 0
                    for byte in value {
                        kindValue = (kindValue << 8) | UInt32(byte)
                    }
                    kind = Int(kindValue)
                }
            default:
                break
            }
            
            index += length
        }
        
        guard let identifier = identifier,
              let pubkey = pubkey,
              let kind = kind else {
            throw NostrError.invalidBech32("Missing required fields in naddr")
        }
        
        return try NAddr(identifier: identifier, pubkey: pubkey, kind: kind, relays: relays.isEmpty ? nil : relays)
    }
}

/// Convenience extensions
public extension String {
    /// Try to decode as any bech32 entity
    var bech32Entity: Bech32Entity? {
        try? Bech32Entity(from: self)
    }
}

public extension PublicKey {
    /// Encode public key as npub
    var npub: String {
        get throws {
            try Bech32Entity.npub(self).encoded
        }
    }
}

public extension PrivateKey {
    /// Encode private key as nsec
    var nsec: String {
        get throws {
            try Bech32Entity.nsec(self).encoded
        }
    }
}

public extension EventID {
    /// Encode event ID as note
    var note: String {
        get throws {
            try Bech32Entity.note(self).encoded
        }
    }
}