import Foundation
@_exported import Crypto
@_exported import CryptoKit

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
    /// - Throws: ``NostrError/invalidEvent(_:)`` if content is too large
    public static func createEvent(
        keyPair: KeyPair,
        kind: EventKind,
        content: String,
        tags: [[String]] = []
    ) throws -> NostrEvent {
        // Validate content size
        try Validation.validateContentSize(content)
        
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
        // Validate event structure first
        try Validation.validateNostrEvent(event)
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
            try Validation.validateEventId(replyTo)
            tags.append(["e", replyTo])
        }
        
        for user in mentionedUsers {
            try Validation.validatePublicKey(user)
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
            throw NostrError.serializationError(type: "metadata", reason: "Failed to convert metadata to UTF-8 string")
        }
        
        return try createEvent(
            keyPair: keyPair,
            kind: .setMetadata,
            content: jsonString
        )
    }
    
    /// Verifies a NIP-05 identifier for a given public key.
    ///
    /// This method fetches the well-known JSON endpoint and verifies that the
    /// identifier correctly maps to the provided public key.
    ///
    /// - Parameters:
    ///   - identifier: The NIP-05 identifier to verify (e.g., "bob@example.com")
    ///   - publicKey: The public key to verify against
    ///   - verifier: Optional custom verifier (defaults to new instance)
    /// - Returns: True if the identifier is valid for the public key
    /// - Throws: Network or parsing errors
    public static func verifyNIP05(
        identifier: String,
        publicKey: PublicKey,
        verifier: NostrNIP05Verifier = NostrNIP05Verifier()
    ) async throws -> Bool {
        try Validation.validatePublicKey(publicKey)
        let nip05Identifier = try NostrNIP05Identifier(identifier: identifier)
        return try await verifier.verify(identifier: nip05Identifier, publicKey: publicKey)
    }
    
    /// Discovers a public key from a NIP-05 identifier.
    ///
    /// This method performs user discovery by fetching the well-known JSON
    /// endpoint and returning the public key mapped to the identifier.
    ///
    /// - Parameters:
    ///   - identifier: The NIP-05 identifier to discover (e.g., "bob@example.com")
    ///   - discovery: Optional custom discovery service (defaults to new instance)
    /// - Returns: Discovery result with public key and relay URLs, or nil if not found
    /// - Throws: Network or parsing errors
    public static func discoverNIP05(
        identifier: String,
        discovery: NostrNIP05Discovery = NostrNIP05Discovery()
    ) async throws -> NostrNIP05DiscoveryResult? {
        let nip05Identifier = try NostrNIP05Identifier(identifier: identifier)
        return try await discovery.discover(identifier: nip05Identifier)
    }
    
    /// Creates a follow list event (NIP-02) containing the user's follows.
    ///
    /// Follow lists are special events that contain a list of profiles being followed.
    /// They can be used for backup, profile discovery, relay sharing, and implementing
    /// petname schemes.
    ///
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - follows: Array of follow entries representing followed profiles
    /// - Returns: A signed follow list event
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createFollowListEvent(
        keyPair: KeyPair,
        follows: [FollowEntry]
    ) throws -> NostrEvent {
        let followList = NostrFollowList(follows: follows)
        let event = followList.createEvent(pubkey: keyPair.publicKey)
        return try keyPair.signEvent(event)
    }
    
    /// Creates an OpenTimestamps attestation event (NIP-03) for a given event.
    ///
    /// OpenTimestamps attestations provide cryptographic proof that a specific event
    /// existed at a certain point in time by anchoring it to the Bitcoin blockchain.
    ///
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - eventId: The ID of the event being attested
    ///   - relayURL: Optional relay URL where the attested event can be found
    ///   - otsData: The raw OTS file data containing the Bitcoin attestation
    /// - Returns: A signed OpenTimestamps attestation event
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createOpenTimestampsEvent(
        keyPair: KeyPair,
        eventId: EventID,
        relayURL: String? = nil,
        otsData: Data
    ) throws -> NostrEvent {
        let attestation = NostrOpenTimestamps(eventId: eventId, relayURL: relayURL, otsData: otsData)
        let event = attestation.createEvent(pubkey: keyPair.publicKey)
        return try keyPair.signEvent(event)
    }
    
    /// Creates an OpenTimestamps attestation event from base64-encoded OTS data.
    ///
    /// This is a convenience method for when you have OTS data in base64 format.
    ///
    /// - Parameters:
    ///   - keyPair: The key pair to sign the event with
    ///   - eventId: The ID of the event being attested
    ///   - relayURL: Optional relay URL where the attested event can be found
    ///   - base64OTSData: The base64-encoded OTS file data
    /// - Returns: A signed OpenTimestamps attestation event
    /// - Throws: ``NostrError/invalidEvent(_:)`` if base64 data is invalid
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public static func createOpenTimestampsEventFromBase64(
        keyPair: KeyPair,
        eventId: EventID,
        relayURL: String? = nil,
        base64OTSData: String
    ) throws -> NostrEvent {
        guard let attestation = NostrOpenTimestamps.fromBase64(
            eventId: eventId,
            relayURL: relayURL,
            base64OTSData: base64OTSData
        ) else {
            throw NostrError.validationError(field: "base64OTSData", reason: "Invalid base64 encoding for OpenTimestamps data")
        }
        
        let event = attestation.createEvent(pubkey: keyPair.publicKey)
        return try keyPair.signEvent(event)
    }
    
    /// Creates an encrypted direct message event (NIP-04) - DEPRECATED.
    ///
    /// **⚠️ SECURITY WARNING**: NIP-04 is deprecated in favor of NIP-17 due to
    /// security vulnerabilities. This method is provided for backward compatibility only.
    ///
    /// Encrypted direct messages use AES-256-CBC encryption with ECDH shared secrets.
    /// They leak metadata and should only be used with AUTH-enabled relays.
    ///
    /// - Parameters:
    ///   - senderKeyPair: The sender's key pair for encryption and signing
    ///   - recipientPublicKey: The recipient's public key
    ///   - message: The plaintext message to encrypt
    ///   - replyToEventId: Optional event ID this message is replying to
    /// - Returns: A signed encrypted direct message event
    /// - Throws: ``NostrError/cryptographyError(_:)`` if encryption or signing fails
    @available(*, deprecated, message: "NIP-04 is deprecated in favor of NIP-17. Use only for backward compatibility.")
    public static func createDirectMessageEvent(
        senderKeyPair: KeyPair,
        recipientPublicKey: PublicKey,
        message: String,
        replyToEventId: EventID? = nil
    ) throws -> NostrEvent {
        let directMessage = try NostrDirectMessage.create(
            senderKeyPair: senderKeyPair,
            recipientPublicKey: recipientPublicKey,
            message: message,
            replyToEventId: replyToEventId
        )
        let event = directMessage.createEvent(pubkey: senderKeyPair.publicKey)
        return try senderKeyPair.signEvent(event)
    }
    
    /// Decrypts an encrypted direct message event (NIP-04) - DEPRECATED.
    ///
    /// **⚠️ SECURITY WARNING**: NIP-04 is deprecated in favor of NIP-17 due to
    /// security vulnerabilities. This method is provided for backward compatibility only.
    ///
    /// - Parameters:
    ///   - event: The encrypted direct message event to decrypt
    ///   - recipientKeyPair: The recipient's key pair for decryption
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/invalidEvent(_:)`` if the event is not a valid direct message
    /// - Throws: ``NostrError/cryptographyError(_:)`` if decryption fails
    @available(*, deprecated, message: "NIP-04 is deprecated in favor of NIP-17. Use only for backward compatibility.")
    public static func decryptDirectMessage(
        event: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> String {
        guard let directMessage = NostrDirectMessage.from(event: event) else {
            throw NostrError.invalidEvent(reason: .invalidKind)
        }
        
        return try directMessage.decrypt(
            with: recipientKeyPair,
            senderPublicKey: event.pubkey
        )
    }
    
    /// Creates an encrypted direct message event using NIP-44 encryption.
    ///
    /// NIP-44 provides better security than NIP-04 with proper padding and
    /// modern encryption (ChaCha20-Poly1305).
    ///
    /// - Parameters:
    ///   - senderKeyPair: The sender's key pair for encryption and signing
    ///   - recipientPublicKey: The recipient's public key
    ///   - message: The plaintext message to encrypt
    ///   - replyToEventId: Optional event ID this message is replying to
    /// - Returns: A signed encrypted direct message event
    /// - Throws: ``NostrError/cryptographyError(_:)`` if encryption or signing fails
    public static func createDirectMessageEventNIP44(
        senderKeyPair: KeyPair,
        recipientPublicKey: PublicKey,
        message: String,
        replyToEventId: EventID? = nil
    ) throws -> NostrEvent {
        // Encrypt the message using NIP-44
        let encryptedContent = try senderKeyPair.encryptNIP44(
            message: message,
            to: recipientPublicKey
        )
        
        // Build tags
        var tags: [[String]] = [["p", recipientPublicKey]]
        
        // Add reply tag if provided
        if let replyToEventId = replyToEventId {
            try Validation.validateEventId(replyToEventId)
            tags.append(["e", replyToEventId])
        }
        
        // Add NIP-44 version tag
        tags.append(["nip44-version", "2"])
        
        // Create and sign the event
        return try createEvent(
            keyPair: senderKeyPair,
            kind: .encryptedDirectMessage,
            content: encryptedContent,
            tags: tags
        )
    }
    
    /// Decrypts an encrypted direct message event using NIP-44.
    ///
    /// - Parameters:
    ///   - event: The encrypted direct message event to decrypt
    ///   - recipientKeyPair: The recipient's key pair for decryption
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/invalidEvent(_:)`` if the event is not a valid direct message
    /// - Throws: ``NostrError/cryptographyError(_:)`` if decryption fails
    public static func decryptDirectMessageNIP44(
        event: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> String {
        guard event.kind == EventKind.encryptedDirectMessage.rawValue else {
            throw NostrError.invalidEvent(reason: .invalidKind)
        }
        
        return try recipientKeyPair.decryptNIP44(
            payload: event.content,
            from: event.pubkey
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
    
    /// Whether this event is a follow list (kind 3).
    public var isFollowList: Bool {
        return kind == EventKind.followList.rawValue
    }
    
    /// Whether this event is an OpenTimestamps attestation (kind 1040).
    public var isOpenTimestamps: Bool {
        return kind == EventKind.openTimestamps.rawValue
    }
    
    /// Whether this event is an encrypted direct message (kind 4) - DEPRECATED.
    @available(*, deprecated, message: "NIP-04 is deprecated in favor of NIP-17.")
    public var isEncryptedDirectMessage: Bool {
        return kind == EventKind.encryptedDirectMessage.rawValue
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
    
    /// Extracts the metadata content as a dictionary (for kind 0 events).
    ///
    /// - Returns: Dictionary of metadata fields, or nil if not a metadata event or invalid JSON
    public var metadataContent: [String: Any]? {
        guard isMetadata else { return nil }
        
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    /// Extracts the NIP-05 identifier from metadata content (for kind 0 events).
    ///
    /// - Returns: The NIP-05 identifier string, or nil if not present or invalid
    public var nip05Identifier: String? {
        return metadataContent?["nip05"] as? String
    }
    
    /// Extracts the parsed NIP-05 identifier from metadata content.
    ///
    /// - Returns: The parsed NIP-05 identifier, or nil if not present or invalid
    public var parsedNIP05Identifier: NostrNIP05Identifier? {
        guard let nip05 = nip05Identifier else { return nil }
        return try? NostrNIP05Identifier(identifier: nip05)
    }
    
    /// Verifies the NIP-05 identifier in this metadata event against the event's public key.
    ///
    /// This method extracts the NIP-05 identifier from the metadata content and verifies
    /// it against the event's public key using the well-known JSON endpoint.
    ///
    /// - Parameter verifier: Optional custom verifier (defaults to new instance)
    /// - Returns: True if the NIP-05 identifier is valid for this event's public key
    /// - Throws: Network or parsing errors
    public func verifyNIP05(verifier: NostrNIP05Verifier = NostrNIP05Verifier()) async throws -> Bool {
        guard let parsedIdentifier = parsedNIP05Identifier else {
            return false
        }
        
        return try await verifier.verify(identifier: parsedIdentifier, publicKey: pubkey)
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
    
    /// Creates a filter for follow lists (kind 3 events).
    ///
    /// - Parameters:
    ///   - authors: Optional array of author public keys to filter by
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for follow list events
    public static func followLists(
        authors: [PublicKey]? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.followList.rawValue],
            limit: limit
        )
    }
    
    /// Creates a filter for OpenTimestamps attestation events (kind 1040).
    ///
    /// - Parameters:
    ///   - authors: Optional array of author public keys to filter by
    ///   - eventIds: Optional array of event IDs being attested to
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for OpenTimestamps attestation events
    public static func openTimestamps(
        authors: [PublicKey]? = nil,
        eventIds: [EventID]? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.openTimestamps.rawValue],
            limit: limit,
            e: eventIds
        )
    }
    
    /// Creates a filter for encrypted direct message events (kind 4) - DEPRECATED.
    /// 
    /// **⚠️ SECURITY WARNING**: NIP-04 is deprecated in favor of NIP-17.
    ///
    /// - Parameters:
    ///   - authors: Optional array of author public keys to filter by
    ///   - recipients: Optional array of recipient public keys to filter by
    ///   - limit: Optional maximum number of events to return
    /// - Returns: A filter configured for encrypted direct message events
    @available(*, deprecated, message: "NIP-04 is deprecated in favor of NIP-17.")
    public static func encryptedDirectMessages(
        authors: [PublicKey]? = nil,
        recipients: [PublicKey]? = nil,
        limit: Int? = nil
    ) -> Filter {
        return Filter(
            authors: authors,
            kinds: [EventKind.encryptedDirectMessage.rawValue],
            limit: limit,
            p: recipients
        )
    }
}
