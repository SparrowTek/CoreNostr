import Foundation

// MARK: - CoreNostr Public API

/// The main entry point for CoreNostr functionality.
/// 
/// CoreNostr provides a convenient, high-level API for common NOSTR operations
/// including key generation, event creation, and verification.
/// 
/// ## Example Usage
/// ```swift
/// // Generate a key pair
/// let keyPair = try CoreNostr.createKeyPair()
/// 
/// // Create a text note
/// let note = try CoreNostr.createTextNote(
///     keyPair: keyPair,
///     content: "Hello, NOSTR world!"
/// )
/// 
/// // Verify the event
/// let isValid = try CoreNostr.verifyEvent(note)
/// ```
public struct CoreNostr {
    /// The current version of the CoreNostr library.
    public static let version = "1.0.0"
    
    /// Creates a new random key pair.
    /// 
    /// - Returns: A new ``KeyPair`` with randomly generated private and public keys
    /// - Throws: ``NostrError/cryptographyError(_:)`` if key generation fails
    public static func createKeyPair() throws -> KeyPair {
        return try KeyPair.generate()
    }
    
    /// Creates and signs a NOSTR event of the specified kind.
    /// 
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - kind: The type of event to create
    ///   - content: The content of the event
    ///   - tags: Optional tags for the event metadata
    /// - Returns: A signed ``NostrEvent`` ready for publishing
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createEvent(
        keyPair: KeyPair,
        kind: EventKind,
        content: String,
        tags: [[String]] = []
    ) throws -> NostrEvent {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: kind.rawValue,
            tags: tags,
            content: content
        )
        return try keyPair.signEvent(event)
    }
    
    /// Verifies the signature and ID of a NOSTR event.
    /// 
    /// - Parameter event: The event to verify
    /// - Returns: `true` if the event is valid, `false` otherwise
    /// - Throws: ``NostrError/invalidEvent(_:)`` if the event ID is invalid
    /// - Throws: ``NostrError/cryptographyError(_:)`` if verification fails
    public static func verifyEvent(_ event: NostrEvent) throws -> Bool {
        return try KeyPair.verifyEvent(event)
    }
    
    /// Creates a text note event with optional reply and mention tags.
    /// 
    /// Text notes are the most common type of NOSTR event, similar to tweets.
    /// They can reference other events (replies) and mention users.
    /// 
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - content: The text content of the note
    ///   - replyTo: Optional event ID this note is replying to
    ///   - mentionedUsers: Optional array of user public keys to mention
    /// - Returns: A signed text note event
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createTextNote(
        keyPair: KeyPair,
        content: String,
        replyTo: EventID? = nil,
        mentionedUsers: [PublicKey] = []
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        if let replyTo = replyTo {
            tags.append(["e", replyTo])
        }
        
        for user in mentionedUsers {
            tags.append(["p", user])
        }
        
        return try createEvent(
            keyPair: keyPair,
            kind: .textNote,
            content: content,
            tags: tags
        )
    }
    
    /// Creates a metadata event containing user profile information.
    /// 
    /// Metadata events (kind 0) contain JSON-encoded profile information
    /// that clients use to display user profiles.
    /// 
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - name: The user's display name
    ///   - about: A description or bio
    ///   - picture: URL to the user's profile picture
    ///   - nip05: NIP-05 identifier (like an email address)
    ///   - lud06: Lightning Address (LNURL-pay)
    ///   - lud16: Lightning Address (newer format)
    /// - Returns: A signed metadata event
    /// - Throws: ``NostrError/serializationError(_:)`` if JSON encoding fails
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createMetadataEvent(
        keyPair: KeyPair,
        name: String?,
        about: String?,
        picture: String?,
        nip05: String? = nil,
        lud06: String? = nil,
        lud16: String? = nil
    ) throws -> NostrEvent {
        var metadata: [String: Any] = [:]
        
        if let name = name { metadata["name"] = name }
        if let about = about { metadata["about"] = about }
        if let picture = picture { metadata["picture"] = picture }
        if let nip05 = nip05 { metadata["nip05"] = nip05 }
        if let lud06 = lud06 { metadata["lud06"] = lud06 }
        if let lud16 = lud16 { metadata["lud16"] = lud16 }
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NostrError.serializationError("Failed to serialize metadata")
        }
        
        return try createEvent(
            keyPair: keyPair,
            kind: .setMetadata,
            content: jsonString
        )
    }
}

// MARK: - Convenience Extensions

/// Extensions to ``NostrEvent`` for common operations and computed properties.
extension NostrEvent {
    /// The creation date of the event as a Swift Date.
    public var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(createdAt))
    }
    
    /// The event kind as an ``EventKind`` enum, if it's a recognized type.
    public var eventKind: EventKind? {
        return EventKind(rawValue: kind)
    }
    
    /// Whether this event is a text note (kind 1).
    public var isTextNote: Bool {
        return kind == EventKind.textNote.rawValue
    }
    
    /// Whether this event is a metadata event (kind 0).
    public var isMetadata: Bool {
        return kind == EventKind.setMetadata.rawValue
    }
    
    /// Array of event IDs referenced by this event ("e" tags).
    public var referencedEvents: [EventID] {
        return tags.compactMap { tag in
            guard tag.count >= 2 && tag[0] == "e" else { return nil }
            return tag[1]
        }
    }
    
    /// Array of user public keys mentioned in this event ("p" tags).
    public var mentionedUsers: [PublicKey] {
        return tags.compactMap { tag in
            guard tag.count >= 2 && tag[0] == "p" else { return nil }
            return tag[1]
        }
    }
}

/// Extensions to ``Filter`` for creating common filter types.
extension Filter {
    /// Creates a filter for text notes (kind 1 events).
    /// 
    /// - Parameters:
    ///   - authors: Optional array of author public keys to filter by
    ///   - since: Optional minimum creation date
    ///   - until: Optional maximum creation date
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for text notes
    public static func textNotes(
        authors: [PublicKey]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.textNote.rawValue],
            since: since,
            until: until,
            limit: limit
        )
    }
    
    /// Creates a filter for metadata events (kind 0 events).
    /// 
    /// - Parameters:
    ///   - authors: Optional array of author public keys to filter by
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for metadata events
    public static func metadata(
        authors: [PublicKey]? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.setMetadata.rawValue],
            limit: limit
        )
    }
    
    /// Creates a filter for replies to a specific event.
    /// 
    /// - Parameters:
    ///   - eventId: The ID of the event to find replies for
    ///   - since: Optional minimum creation date
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for replies to the specified event
    public static func replies(
        to eventId: EventID,
        since: Date? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            kinds: [EventKind.textNote.rawValue],
            since: since,
            limit: limit,
            e: [eventId]
        )
    }
}
