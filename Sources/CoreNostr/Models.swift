import Foundation
import Crypto

// MARK: - Type Aliases

/// A unique identifier for a NOSTR event, represented as a 64-character hexadecimal string.
/// 
/// Event IDs are calculated by taking the SHA256 hash of the serialized event data
/// according to NIP-01 specification.
public typealias EventID = String

/// A NOSTR public key, represented as a 64-character hexadecimal string.
/// 
/// Public keys are derived from secp256k1 private keys and serve as user identities
/// in the NOSTR protocol.
public typealias PublicKey = String

/// A NOSTR private key, represented as a 64-character hexadecimal string.
/// 
/// Private keys are used to sign events and should be kept secret.
public typealias PrivateKey = String

/// A Schnorr signature over secp256k1, represented as a 128-character hexadecimal string.
/// 
/// Signatures are created by signing the serialized event data with the corresponding private key.
public typealias Signature = String

// MARK: - NostrEvent

/// A NOSTR event following the NIP-01 specification.
/// 
/// Events are the fundamental data structure in NOSTR, containing user-generated content
/// along with metadata and cryptographic signatures for verification.
/// 
/// ## Example
/// ```swift
/// let event = NostrEvent(
///     pubkey: keyPair.publicKey,
///     kind: 1,
///     tags: [["p", "user-pubkey"]],
///     content: "Hello, NOSTR!"
/// )
/// ```
/// 
/// - Note: Events must be signed before being published to relays.
public struct NostrEvent: Codable, Hashable, Sendable {
    /// The unique identifier for this event, calculated as SHA256 hash of serialized event data.
    public let id: EventID
    
    /// The public key of the event author in hexadecimal format.
    public let pubkey: PublicKey
    
    /// Unix timestamp when the event was created.
    public let createdAt: Int64
    
    /// The event kind, determining how the event should be interpreted.
    /// 
    /// Common kinds include:
    /// - `0`: Set metadata
    /// - `1`: Text note
    /// - `2`: Recommend server
    public let kind: Int
    
    /// Tags provide additional metadata about the event.
    /// 
    /// Each tag is an array of strings where the first element indicates the tag type:
    /// - `["e", "event-id"]` - References another event
    /// - `["p", "pubkey"]` - References a user
    /// - `["t", "hashtag"]` - Hashtag
    public let tags: [[String]]
    
    /// The content of the event, format depends on the event kind.
    public let content: String
    
    /// The Schnorr signature of the event, verifying authenticity.
    public let sig: Signature
    
    private enum CodingKeys: String, CodingKey {
        case id, pubkey, kind, tags, content, sig
        case createdAt = "created_at"
    }
    
    /// Creates a complete NOSTR event with all required fields.
    /// 
    /// - Parameters:
    ///   - id: The unique event identifier
    ///   - pubkey: The author's public key
    ///   - createdAt: Unix timestamp of creation
    ///   - kind: The event kind
    ///   - tags: Array of tag arrays for metadata
    ///   - content: The event content
    ///   - sig: The event signature
    public init(
        id: EventID,
        pubkey: PublicKey,
        createdAt: Int64,
        kind: Int,
        tags: [[String]],
        content: String,
        sig: Signature
    ) {
        self.id = id
        self.pubkey = pubkey
        self.createdAt = createdAt
        self.kind = kind
        self.tags = tags
        self.content = content
        self.sig = sig
    }
    
    /// Creates an unsigned NOSTR event ready for signing.
    /// 
    /// This initializer creates an event without an ID or signature,
    /// which must be added later through the signing process.
    /// 
    /// - Parameters:
    ///   - pubkey: The author's public key
    ///   - createdAt: Creation timestamp (defaults to current time)
    ///   - kind: The event kind
    ///   - tags: Array of tag arrays for metadata (defaults to empty)
    ///   - content: The event content
    public init(
        pubkey: PublicKey,
        createdAt: Date = Date(),
        kind: Int,
        tags: [[String]] = [],
        content: String
    ) {
        self.pubkey = pubkey
        self.createdAt = Int64(createdAt.timeIntervalSince1970)
        self.kind = kind
        self.tags = tags
        self.content = content
        self.id = ""
        self.sig = ""
    }
    
    /// Serializes the event for signing according to NIP-01.
    /// 
    /// The serialization format is a JSON array containing:
    /// `[0, pubkey, created_at, kind, tags, content]`
    /// 
    /// - Returns: JSON string representation for signing
    public func serializedForSigning() -> String {
        let array: [Any] = [
            0,
            pubkey,
            createdAt,
            kind,
            tags,
            content
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: array, options: [.withoutEscapingSlashes]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ""
        }
        
        return jsonString
    }
    
    /// Calculates the event ID as SHA256 hash of the serialized event.
    /// 
    /// - Returns: 64-character hexadecimal event ID
    public func calculateId() -> EventID {
        let serialized = serializedForSigning()
        let data = Data(serialized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Creates a new event with the provided signature and calculated ID.
    /// 
    /// - Parameter signature: The Schnorr signature for this event
    /// - Returns: A complete, signed event ready for publishing
    public func withSignature(_ signature: Signature) -> NostrEvent {
        let id = calculateId()
        return NostrEvent(
            id: id,
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content,
            sig: signature
        )
    }
}

// MARK: - Event Kinds

/// Standardized event kinds defined by NIP-01.
/// 
/// Event kinds determine how the event content should be interpreted by clients.
public enum EventKind: Int, CaseIterable, Sendable {
    /// Set metadata about the user (profile information)
    case setMetadata = 0
    
    /// Text note (tweet-like message)
    case textNote = 1
    
    /// Recommend a relay server
    case recommendServer = 2
    
    /// Human-readable description of the event kind.
    public var description: String {
        switch self {
        case .setMetadata: return "Set Metadata"
        case .textNote: return "Text Note"
        case .recommendServer: return "Recommend Server"
        }
    }
}

// MARK: - Filter

/// A filter for requesting specific events from relays.
/// 
/// Filters allow clients to request only events that match certain criteria,
/// such as specific authors, event kinds, or time ranges.
/// 
/// ## Example
/// ```swift
/// let filter = Filter(
///     authors: ["user-pubkey"],
///     kinds: [1], // Text notes only
///     limit: 20
/// )
/// ```
public struct Filter: Codable, Sendable {
    /// Filter by specific event IDs
    public var ids: [EventID]?
    
    /// Filter by author public keys
    public var authors: [PublicKey]?
    
    /// Filter by event kinds
    public var kinds: [Int]?
    
    /// Filter events created after this timestamp
    public var since: Int64?
    
    /// Filter events created before this timestamp
    public var until: Int64?
    
    /// Maximum number of events to return
    public var limit: Int?
    
    /// Filter by referenced event IDs ("e" tags)
    public var e: [String]?
    
    /// Filter by referenced public keys ("p" tags)
    public var p: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case ids, authors, kinds, since, until, limit
        case e = "#e"
        case p = "#p"
    }
    
    /// Creates a filter with the specified criteria.
    /// 
    /// - Parameters:
    ///   - ids: Specific event IDs to match
    ///   - authors: Author public keys to match
    ///   - kinds: Event kinds to match
    ///   - since: Minimum creation time
    ///   - until: Maximum creation time
    ///   - limit: Maximum number of events to return
    ///   - e: Referenced event IDs to match
    ///   - p: Referenced public keys to match
    public init(
        ids: [EventID]? = nil,
        authors: [PublicKey]? = nil,
        kinds: [Int]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil,
        e: [String]? = nil,
        p: [String]? = nil
    ) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since.map { Int64($0.timeIntervalSince1970) }
        self.until = until.map { Int64($0.timeIntervalSince1970) }
        self.limit = limit
        self.e = e
        self.p = p
    }
}

// MARK: - Errors

/// Errors that can occur when working with NOSTR events and networking.
public enum NostrError: Error, LocalizedError, Sendable {
    /// An event failed validation or contains invalid data
    case invalidEvent(String)
    
    /// A cryptographic operation failed
    case cryptographyError(String)
    
    /// A network operation failed
    case networkError(String)
    
    /// JSON serialization or deserialization failed
    case serializationError(String)
    
    /// Localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        case .cryptographyError(let message):
            return "Cryptography error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        }
    }
}