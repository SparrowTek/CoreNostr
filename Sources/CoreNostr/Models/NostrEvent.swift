//
//  NostrEvent.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation
import Crypto

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
    /// - Throws: NostrError if validation fails
    public init(
        id: EventID,
        pubkey: PublicKey,
        createdAt: Int64,
        kind: Int,
        tags: [[String]],
        content: String,
        sig: Signature
    ) throws {
        try Validation.validateEventId(id)
        try Validation.validatePublicKey(pubkey)
        try Validation.validateSignature(sig)
        
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
            unvalidatedId: id,
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content,
            sig: signature
        )
    }
    
    /// Creates a complete NOSTR event without validation (internal use only).
    ///
    /// - Parameters:
    ///   - id: The unique event identifier
    ///   - pubkey: The author's public key
    ///   - createdAt: Unix timestamp of creation
    ///   - kind: The event kind
    ///   - tags: Array of tag arrays for metadata
    ///   - content: The event content
    ///   - sig: The event signature
    /// - Warning: This initializer does not validate input.
    internal init(
        unvalidatedId id: EventID,
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
}

