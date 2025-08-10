import Foundation

/// NIP-19: bech32-encoded entities
/// https://github.com/nostr-protocol/nips/blob/master/19.md
///
/// Bech32 encoding provides a human-readable format for NOSTR identifiers
/// with built-in error detection. This makes sharing public keys, event IDs,
/// and other NOSTR data more user-friendly and less error-prone.
///
/// ## Supported Entity Types
/// - `npub`: Public keys (32 bytes)
/// - `nsec`: Private keys (32 bytes) - handle with care!
/// - `note`: Event IDs (32 bytes)
/// - `nprofile`: Public key with relay hints
/// - `nevent`: Event with metadata (relay hints, author, kind)
/// - `nrelay`: Relay URLs
/// - `naddr`: Replaceable event coordinates
///
/// ## Example Usage
/// ```swift
/// // Encode a public key
/// let npub = try Bech32Entity.npub(publicKey).encoded
/// // Result: "npub1..."
///
/// // Decode any bech32 string
/// let entity = try Bech32Entity(from: "npub1...")
/// ```
public enum Bech32Entity: Sendable {
    /// Public key encoded as npub
    case npub(String)
    
    /// Private key encoded as nsec - handle with extreme care!
    case nsec(String)
    
    /// Event ID encoded as note
    case note(String)
    
    /// Profile with public key and relay hints
    case nprofile(NProfile)
    
    /// Event with additional metadata
    case nevent(NEvent)
    
    /// Relay URL encoded for sharing
    case nrelay(String)
    
    /// Replaceable event coordinate
    case naddr(NAddr)
}

/// Profile information containing a public key and relay hints.
///
/// NProfile encodes a public key along with relay URLs where the user
/// can typically be found. This helps clients discover where to find
/// a user's events without having to query all known relays.
///
/// ## Example
/// ```swift
/// let profile = try NProfile(
///     pubkey: "abc123...",
///     relays: ["wss://relay.example.com", "wss://relay2.example.com"]
/// )
/// ```
public struct NProfile: Sendable {
    /// The user's public key in hexadecimal format (64 characters).
    public let pubkey: String
    
    /// Relay URLs where this user's events can be found.
    /// These are hints to help clients efficiently locate the user's content.
    public let relays: [String]
    
    /// Creates a new NProfile with validation.
    ///
    /// - Parameters:
    ///   - pubkey: The user's public key (64 hex characters)
    ///   - relays: Array of relay URLs (must use ws:// or wss://)
    /// - Throws: ``NostrError`` if pubkey or relay URLs are invalid
    public init(pubkey: String, relays: [String] = []) throws {
        try Validation.validatePublicKey(pubkey)
        for relay in relays {
            try Validation.validateRelayURL(relay)
        }
        self.pubkey = pubkey
        self.relays = relays
    }
}

/// Event reference with additional metadata.
///
/// NEvent encodes an event ID along with optional metadata that helps
/// clients efficiently locate and display the event. This includes relay
/// hints, the author's public key, and the event kind.
///
/// ## Example
/// ```swift
/// let event = try NEvent(
///     eventId: "abc123...",
///     relays: ["wss://relay.example.com"],
///     author: "def456...",
///     kind: 1
/// )
/// ```
public struct NEvent: Sendable {
    /// The event ID in hexadecimal format (64 characters).
    public let eventId: String
    
    /// Relay URLs where this event can be found.
    /// These are hints to help clients efficiently locate the event.
    public let relays: [String]?
    
    /// The author's public key (optional).
    /// Included to help clients display event previews without fetching.
    public let author: String?
    
    /// The event kind (optional).
    /// Helps clients determine how to render the event.
    public let kind: Int?
    
    /// Creates a new NEvent with validation.
    ///
    /// - Parameters:
    ///   - eventId: The event ID (64 hex characters)
    ///   - relays: Optional array of relay URLs where the event can be found
    ///   - author: Optional author public key (64 hex characters)
    ///   - kind: Optional event kind number
    /// - Throws: ``NostrError`` if eventId, author, or relay URLs are invalid
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

/// Replaceable event coordinate.
///
/// NAddr uniquely identifies a replaceable or parameterized replaceable event
/// using a combination of the author's public key, event kind, and an identifier.
/// This allows referencing events that may be updated over time while maintaining
/// a stable reference.
///
/// ## Example
/// ```swift
/// let addr = try NAddr(
///     identifier: "my-article",
///     pubkey: "abc123...",
///     kind: 30023,  // Long-form content
///     relays: ["wss://relay.example.com"]
/// )
/// ```
public struct NAddr: Sendable {
    /// The event's d-tag identifier.
    /// For parameterized replaceable events, this uniquely identifies the event
    /// within the author's events of the same kind.
    public let identifier: String
    
    /// The author's public key in hexadecimal format (64 characters).
    public let pubkey: String
    
    /// The event kind.
    /// Must be a replaceable or parameterized replaceable event kind.
    public let kind: Int
    
    /// Relay URLs where this event can be found.
    /// These are hints to help clients efficiently locate the event.
    public let relays: [String]?
    
    /// Creates a new NAddr with validation.
    ///
    /// - Parameters:
    ///   - identifier: The event's d-tag identifier
    ///   - pubkey: The author's public key (64 hex characters)
    ///   - kind: The event kind (typically 30000+)
    ///   - relays: Optional array of relay URLs where the event can be found
    /// - Throws: ``NostrError`` if pubkey or relay URLs are invalid
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

/// Bech32 encoding/decoding utilities for NOSTR entities.
///
/// This struct provides low-level bech32 encoding and decoding functionality
/// following the bech32 specification with NOSTR-specific adaptations.
/// Most users should use the higher-level `Bech32Entity` API instead.
///
/// ## Implementation Details
/// - Uses the standard bech32 character set
/// - Implements checksum calculation and verification
/// - Supports TLV (Type-Length-Value) encoding for complex entities
public struct Bech32: Sendable {
    private static let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    private static let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    
    /// Human-readable part (HRP) for each NOSTR entity type.
    ///
    /// The HRP identifies the type of data encoded in the bech32 string,
    /// allowing decoders to handle each type appropriately.
    public enum HRP: String, Sendable {
        /// Public key (32 bytes)
        case npub = "npub"
        
        /// Secret/private key (32 bytes) - handle with care!
        case nsec = "nsec"
        
        /// Event ID (32 bytes)
        case note = "note"
        
        /// Profile with TLV-encoded metadata
        case nprofile = "nprofile"
        
        /// Event with TLV-encoded metadata
        case nevent = "nevent"
        
        /// Relay URL
        case nrelay = "nrelay"
        
        /// Address for replaceable events
        case naddr = "naddr"
    }
    
    /// Encodes data with a human-readable part (HRP) into bech32 format.
    ///
    /// - Parameters:
    ///   - hrp: The human-readable part (e.g., "npub", "nsec")
    ///   - data: The data to encode
    /// - Returns: Bech32-encoded string
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if encoding fails
    public static func encode(hrp: String, data: Data) throws -> String {
        let values = try convertBits(from: Array(data), fromBits: 8, toBits: 5, pad: true)
        let checksum = createChecksum(hrp: hrp, values: values)
        let combined = values + checksum
        
        let encoded = combined.map { charset[charset.index(charset.startIndex, offsetBy: Int($0))] }
        return hrp + "1" + String(encoded)
    }
    
    /// Decodes a bech32 string into its components.
    ///
    /// - Parameter string: The bech32-encoded string to decode
    /// - Returns: A tuple containing the HRP and decoded data
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if decoding fails or checksum is invalid
    public static func decode(_ string: String) throws -> (hrp: String, data: Data) {
        guard let separatorIndex = string.lastIndex(of: "1") else {
            throw NostrError.invalidBech32(entity: "bech32", reason: "No separator character '1' found")
        }
        
        let hrp = String(string[..<separatorIndex]).lowercased()
        let dataString = String(string[string.index(after: separatorIndex)...]).lowercased()
        
        // Verify charset
        for char in dataString {
            guard charset.contains(char) else {
                throw NostrError.invalidBech32(entity: "bech32", reason: "Invalid character '\(char)' in HRP")
            }
        }
        
        // Convert to values
        let values = try dataString.map { char -> UInt8 in
            guard let index = charset.firstIndex(of: char) else {
                throw NostrError.invalidBech32(entity: "bech32", reason: "Invalid character found in data part")
            }
            return UInt8(charset.distance(from: charset.startIndex, to: index))
        }
        
        // Verify checksum
        guard values.count >= 6 else {
            throw NostrError.invalidBech32(entity: "bech32", reason: "Data part too short for valid checksum")
        }
        
        let checksumLength = 6
        let dataValues = Array(values.dropLast(checksumLength))
        let checksum = Array(values.suffix(checksumLength))
        let expectedChecksum = createChecksum(hrp: hrp, values: dataValues)
        
        guard checksum == expectedChecksum else {
            throw NostrError.invalidBech32(entity: "bech32", reason: "Checksum verification failed")
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
                throw NostrError.invalidBech32(entity: "bech32", reason: "Invalid data for 5-bit to 8-bit conversion")
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
            throw NostrError.invalidBech32(entity: "bech32", reason: "Invalid padding bits in last byte")
        } else if ((acc << (toBits - bits)) & maxv) != 0 {
            throw NostrError.invalidBech32(entity: "bech32", reason: "Invalid padding bits in last byte")
        }
        
        return ret
    }
}

// MARK: - Bech32Entity Encoding/Decoding

public extension Bech32Entity {
    /// Encodes this entity to its bech32 string representation.
    ///
    /// The encoding format depends on the entity type:
    /// - Simple entities (npub, nsec, note) are encoded directly
    /// - Complex entities (nprofile, nevent, naddr) use TLV encoding
    ///
    /// ## Example
    /// ```swift
    /// let pubkey = "abc123..."
    /// let npub = try Bech32Entity.npub(pubkey).encoded
    /// // Result: "npub1..."
    /// ```
    ///
    /// - Returns: The bech32-encoded string
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if encoding fails
    var encoded: String {
        get throws {
            switch self {
            case .npub(let pubkey):
                guard let data = Data(hex: pubkey) else {
                    throw NostrError.invalidBech32(entity: "npub", reason: "Invalid hexadecimal format for public key")
                }
                return try Bech32.encode(hrp: Bech32.HRP.npub.rawValue, data: data)
                
            case .nsec(let privkey):
                guard let data = Data(hex: privkey) else {
                    throw NostrError.invalidBech32(entity: "nsec", reason: "Invalid hexadecimal format for private key")
                }
                return try Bech32.encode(hrp: Bech32.HRP.nsec.rawValue, data: data)
                
            case .note(let eventId):
                guard let data = Data(hex: eventId) else {
                    throw NostrError.invalidBech32(entity: "note", reason: "Invalid hexadecimal format for event ID")
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
    
    /// Creates a Bech32Entity by decoding a bech32 string.
    ///
    /// Automatically detects the entity type from the HRP and decodes accordingly.
    /// For complex entities (nprofile, nevent, naddr), TLV data is parsed to
    /// extract all embedded information.
    ///
    /// ## Example
    /// ```swift
    /// let entity = try Bech32Entity(from: "npub1...")
    /// switch entity {
    /// case .npub(let pubkey):
    ///     print("Public key: \(pubkey)")
    /// default:
    ///     break
    /// }
    /// ```
    ///
    /// - Parameter string: The bech32-encoded string to decode
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if decoding fails or format is invalid
    init(from string: String) throws {
        let (hrp, data) = try Bech32.decode(string)
        
        switch hrp {
        case Bech32.HRP.npub.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32(entity: "npub", reason: "Public key must be 32 bytes, got \(data.count)")
            }
            self = .npub(data.hex)
            
        case Bech32.HRP.nsec.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32(entity: "nsec", reason: "Private key must be 32 bytes, got \(data.count)")
            }
            self = .nsec(data.hex)
            
        case Bech32.HRP.note.rawValue:
            guard data.count == 32 else {
                throw NostrError.invalidBech32(entity: "note", reason: "Event ID must be 32 bytes, got \(data.count)")
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
                throw NostrError.invalidBech32(entity: "nrelay", reason: "Invalid relay URL format")
            }
            self = .nrelay(url)
            
        case Bech32.HRP.naddr.rawValue:
            let addr = try Self.decodeTLVAddr(from: data)
            self = .naddr(addr)
            
        default:
            throw NostrError.invalidBech32(entity: "bech32", reason: "Unknown HRP prefix: '\(hrp)'. Expected npub, nsec, note, nprofile, nevent, nrelay, or naddr")
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
            throw NostrError.invalidBech32(entity: "nprofile", reason: "Invalid hexadecimal format for public key")
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
            throw NostrError.invalidBech32(entity: "nevent", reason: "Invalid hexadecimal format for event ID")
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
                throw NostrError.invalidBech32(entity: "nevent", reason: "Invalid hexadecimal format for author public key")
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
            throw NostrError.invalidBech32(entity: "naddr", reason: "Invalid hexadecimal format for public key")
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
                throw NostrError.invalidBech32(entity: "TLV", reason: "Invalid TLV format: insufficient data for length")
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
            throw NostrError.invalidBech32(entity: "nprofile", reason: "Missing required public key field")
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
                throw NostrError.invalidBech32(entity: "TLV", reason: "Invalid TLV format: insufficient data for length")
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
            throw NostrError.invalidBech32(entity: "nevent", reason: "Missing required event ID field")
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
                throw NostrError.invalidBech32(entity: "TLV", reason: "Invalid TLV format: insufficient data for length")
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
            throw NostrError.invalidBech32(entity: "naddr", reason: "Missing required fields: identifier, relay, pubkey, or kind")
        }
        
        return try NAddr(identifier: identifier, pubkey: pubkey, kind: kind, relays: relays.isEmpty ? nil : relays)
    }
}

// MARK: - Convenience Extensions

public extension String {
    /// Attempts to decode this string as a bech32-encoded NOSTR entity.
    ///
    /// This is a convenience property that tries to decode the string without
    /// throwing errors. Useful for checking if a string is a valid bech32 entity.
    ///
    /// ## Example
    /// ```swift
    /// if let entity = "npub1...".bech32Entity {
    ///     switch entity {
    ///     case .npub(let pubkey):
    ///         print("Valid public key: \(pubkey)")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: The decoded entity, or nil if decoding fails
    var bech32Entity: Bech32Entity? {
        try? Bech32Entity(from: self)
    }
}

public extension PublicKey {
    /// Encodes this public key as an npub bech32 string.
    ///
    /// ## Example
    /// ```swift
    /// let pubkey = "abc123..."
    /// let npub = try pubkey.npub
    /// // Result: "npub1..."
    /// ```
    ///
    /// - Returns: The npub-encoded string
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if encoding fails
    var npub: String {
        get throws {
            try Bech32Entity.npub(self).encoded
        }
    }
}

public extension PrivateKey {
    /// Encodes this private key as an nsec bech32 string.
    ///
    /// **⚠️ SECURITY WARNING**: Never share nsec strings! They contain
    /// your private key and grant full access to your NOSTR identity.
    ///
    /// ## Example
    /// ```swift
    /// let privkey = "def456..."
    /// let nsec = try privkey.nsec
    /// // Result: "nsec1..."
    /// ```
    ///
    /// - Returns: The nsec-encoded string
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if encoding fails
    var nsec: String {
        get throws {
            try Bech32Entity.nsec(self).encoded
        }
    }
}

public extension EventID {
    /// Encodes this event ID as a note bech32 string.
    ///
    /// ## Example
    /// ```swift
    /// let eventId = "789abc..."
    /// let note = try eventId.note
    /// // Result: "note1..."
    /// ```
    ///
    /// - Returns: The note-encoded string
    /// - Throws: ``NostrError/invalidBech32(entity:reason:)`` if encoding fails
    var note: String {
        get throws {
            try Bech32Entity.note(self).encoded
        }
    }
}