//
//  NIP17.swift
//  CoreNostr
//
//  NIP-17: Private Direct Messages
//  https://github.com/nostr-protocol/nips/blob/master/17.md
//

import Foundation

/// NIP-17 Private Direct Messages implementation
public enum NIP17 {
    
    /// Errors that can occur during DM operations
    public enum DMError: LocalizedError {
        case invalidMessage
        case invalidRecipients
        case encryptionFailed
        case decryptionFailed
        case invalidSender
        
        public var errorDescription: String? {
            switch self {
            case .invalidMessage:
                return "Invalid message content"
            case .invalidRecipients:
                return "Invalid or empty recipients list"
            case .encryptionFailed:
                return "Failed to encrypt message"
            case .decryptionFailed:
                return "Failed to decrypt message"
            case .invalidSender:
                return "Sender verification failed"
            }
        }
    }
    
    /// Create a direct message event
    /// - Parameters:
    ///   - content: The message content
    ///   - senderKeyPair: The sender's key pair
    ///   - recipientPublicKeys: Array of recipient public keys
    ///   - replyTo: Optional event ID this is replying to
    ///   - subject: Optional conversation subject/title
    ///   - relayUrls: Optional relay URLs for recipients
    /// - Returns: Array of gift-wrapped events (one per recipient + one for sender)
    public static func createDirectMessage(
        content: String,
        senderKeyPair: KeyPair,
        recipientPublicKeys: [String],
        replyTo: String? = nil,
        subject: String? = nil,
        relayUrls: [String: String] = [:]
    ) throws -> [NostrEvent] {
        guard !recipientPublicKeys.isEmpty else {
            throw DMError.invalidRecipients
        }
        
        guard !content.isEmpty else {
            throw DMError.invalidMessage
        }
        
        // Create tags for the DM event
        var tags: [[String]] = []
        
        // Add p tags for recipients
        for recipientPubkey in recipientPublicKeys {
            if let relayUrl = relayUrls[recipientPubkey] {
                tags.append(["p", recipientPubkey, relayUrl])
            } else {
                tags.append(["p", recipientPubkey])
            }
        }
        
        // Add reply tag if applicable
        if let replyTo = replyTo {
            tags.append(["e", replyTo])
        }
        
        // Add subject tag if provided
        if let subject = subject {
            tags.append(["subject", subject])
        }
        
        // Create the rumor event (unsigned kind 14)
        let dmEvent = NostrEvent(
            unvalidatedId: "", // Will be calculated when needed
            pubkey: senderKeyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.directMessage,
            tags: tags,
            content: content,
            sig: "" // Rumor - not signed
        )
        
        var giftWraps: [NostrEvent] = []
        
        // Create gift wrap for each recipient
        for recipientPubkey in recipientPublicKeys {
            let seal = try NIP59.createSeal(
                rumor: dmEvent,
                senderKeyPair: senderKeyPair,
                recipientPublicKey: recipientPubkey
            )
            
            let giftWrap = try NIP59.createGiftWrap(
                seal: seal,
                recipientPublicKey: recipientPubkey,
                relayUrl: relayUrls[recipientPubkey]
            )
            
            giftWraps.append(giftWrap)
        }
        
        // Create gift wrap for sender (for their own records)
        let senderSeal = try NIP59.createSeal(
            rumor: dmEvent,
            senderKeyPair: senderKeyPair,
            recipientPublicKey: senderKeyPair.publicKey
        )
        
        let senderGiftWrap = try NIP59.createGiftWrap(
            seal: senderSeal,
            recipientPublicKey: senderKeyPair.publicKey
        )
        
        giftWraps.append(senderGiftWrap)
        
        return giftWraps
    }
    
    /// Create a file message event
    /// - Parameters:
    ///   - fileUrl: URL of the encrypted file
    ///   - fileType: MIME type of the file before encryption
    ///   - encryptionKey: Key used to encrypt the file
    ///   - encryptionNonce: Nonce used to encrypt the file
    ///   - fileHash: SHA-256 hash of the encrypted file
    ///   - senderKeyPair: The sender's key pair
    ///   - recipientPublicKeys: Array of recipient public keys
    ///   - additionalMetadata: Optional additional metadata (size, dim, blurhash, etc.)
    /// - Returns: Array of gift-wrapped events
    public static func createFileMessage(
        fileUrl: String,
        fileType: String,
        encryptionKey: String,
        encryptionNonce: String,
        fileHash: String,
        senderKeyPair: KeyPair,
        recipientPublicKeys: [String],
        replyTo: String? = nil,
        subject: String? = nil,
        additionalMetadata: [String: String] = [:],
        relayUrls: [String: String] = [:]
    ) throws -> [NostrEvent] {
        guard !recipientPublicKeys.isEmpty else {
            throw DMError.invalidRecipients
        }
        
        // Create tags for the file event
        var tags: [[String]] = []
        
        // Add p tags for recipients
        for recipientPubkey in recipientPublicKeys {
            if let relayUrl = relayUrls[recipientPubkey] {
                tags.append(["p", recipientPubkey, relayUrl])
            } else {
                tags.append(["p", recipientPubkey])
            }
        }
        
        // Add reply tag if applicable
        if let replyTo = replyTo {
            tags.append(["e", replyTo, "", "reply"])
        }
        
        // Add subject tag if provided
        if let subject = subject {
            tags.append(["subject", subject])
        }
        
        // Add file metadata tags
        tags.append(["file-type", fileType])
        tags.append(["encryption-algorithm", "aes-gcm"])
        tags.append(["decryption-key", encryptionKey])
        tags.append(["decryption-nonce", encryptionNonce])
        tags.append(["x", fileHash])
        
        // Add additional metadata
        for (key, value) in additionalMetadata {
            switch key {
            case "ox", "size", "dim", "blurhash", "thumb", "fallback":
                tags.append([key, value])
            default:
                continue // Ignore unknown metadata
            }
        }
        
        // Create the rumor event (unsigned kind 15)
        let fileEvent = NostrEvent(
            unvalidatedId: "",
            pubkey: senderKeyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.fileMessage,
            tags: tags,
            content: fileUrl,
            sig: ""
        )
        
        var giftWraps: [NostrEvent] = []
        
        // Create gift wrap for each recipient
        for recipientPubkey in recipientPublicKeys {
            let seal = try NIP59.createSeal(
                rumor: fileEvent,
                senderKeyPair: senderKeyPair,
                recipientPublicKey: recipientPubkey
            )
            
            let giftWrap = try NIP59.createGiftWrap(
                seal: seal,
                recipientPublicKey: recipientPubkey,
                relayUrl: relayUrls[recipientPubkey]
            )
            
            giftWraps.append(giftWrap)
        }
        
        // Create gift wrap for sender
        let senderSeal = try NIP59.createSeal(
            rumor: fileEvent,
            senderKeyPair: senderKeyPair,
            recipientPublicKey: senderKeyPair.publicKey
        )
        
        let senderGiftWrap = try NIP59.createGiftWrap(
            seal: senderSeal,
            recipientPublicKey: senderKeyPair.publicKey
        )
        
        giftWraps.append(senderGiftWrap)
        
        return giftWraps
    }
    
    /// Receive and decrypt a direct message
    /// - Parameters:
    ///   - giftWrap: The gift wrap event
    ///   - recipientKeyPair: The recipient's key pair
    /// - Returns: The decrypted message event and sender's public key
    public static func receiveDirectMessage(
        _ giftWrap: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> (message: NostrEvent, senderPubkey: String) {
        // Unwrap and open the gift
        let (rumor, seal) = try NIP59.unwrapAndOpen(
            giftWrap,
            recipientKeyPair: recipientKeyPair
        )
        
        // Verify it's a DM event
        guard rumor.kind == EventKind.directMessage ||
              rumor.kind == EventKind.fileMessage else {
            throw DMError.invalidMessage
        }
        
        // Verify sender matches
        guard rumor.pubkey == seal.pubkey else {
            throw DMError.invalidSender
        }
        
        return (rumor, seal.pubkey)
    }
    
    /// Extract conversation participants from a DM event
    /// - Parameter event: The DM event (rumor)
    /// - Returns: Set of participant public keys including sender
    public static func extractParticipants(from event: NostrEvent) -> Set<String> {
        var participants = Set<String>()
        
        // Add sender
        participants.insert(event.pubkey)
        
        // Add recipients from p tags
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "p" {
                participants.insert(tag[1])
            }
        }
        
        return participants
    }
    
    /// Extract conversation subject from a DM event
    /// - Parameter event: The DM event (rumor)
    /// - Returns: The subject if present
    public static func extractSubject(from event: NostrEvent) -> String? {
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "subject" {
                return tag[1]
            }
        }
        return nil
    }
    
    /// Check if a DM event is a reply
    /// - Parameter event: The DM event (rumor)
    /// - Returns: The event ID being replied to, if any
    public static func extractReplyTo(from event: NostrEvent) -> String? {
        for tag in event.tags {
            if tag.count >= 2 && tag[0] == "e" {
                return tag[1]
            }
        }
        return nil
    }
    
    /// Create DM inbox preference event (kind 10050)
    /// - Parameters:
    ///   - relayUrls: List of preferred relay URLs for receiving DMs
    ///   - keyPair: User's key pair
    /// - Returns: Signed kind 10050 event
    public static func createInboxPreference(
        relayUrls: [String],
        keyPair: KeyPair
    ) throws -> NostrEvent {
        var tags: [[String]] = []
        
        for relayUrl in relayUrls {
            tags.append(["relay", relayUrl])
        }
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.dmInboxPreference,
            tags: tags,
            content: ""
        )
        
        return try keyPair.signEvent(event)
    }
}

// MARK: - EventKind Constants

extension EventKind {
    /// Direct message event (NIP-17)
    public static let directMessage = 14
    
    /// File message event (NIP-17)
    public static let fileMessage = 15
    
    /// DM inbox preference (NIP-17)
    public static let dmInboxPreference = 10050
}

// MARK: - Filter Extensions for DMs

public extension Filter {
    /// Create a filter for receiving gift-wrapped DMs
    /// - Parameters:
    ///   - recipientPubkey: The recipient's public key
    ///   - since: Optional timestamp to filter events after
    ///   - limit: Maximum number of events to return
    /// - Returns: A filter for gift-wrapped events
    static func giftWrappedDMs(
        recipient recipientPubkey: String,
        since: Int64? = nil,
        limit: Int? = nil
    ) -> Filter {
        var filter = Filter()
        filter.kinds = [EventKind.giftWrap]
        filter.p = [recipientPubkey]
        filter.since = since
        filter.limit = limit
        return filter
    }
    
    /// Create a filter for DM inbox preferences
    /// - Parameter pubkeys: Public keys to get preferences for
    /// - Returns: A filter for kind 10050 events
    static func dmInboxPreferences(for pubkeys: [String]) -> Filter {
        var filter = Filter()
        filter.kinds = [EventKind.dmInboxPreference]
        filter.authors = pubkeys
        filter.limit = pubkeys.count
        return filter
    }
}