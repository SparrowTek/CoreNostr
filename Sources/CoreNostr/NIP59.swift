//
//  NIP59.swift
//  CoreNostr
//
//  NIP-59: Gift Wrap
//  https://github.com/nostr-protocol/nips/blob/master/59.md
//

import Foundation

/// NIP-59 Gift Wrap implementation
public enum NIP59 {
    
    /// Errors that can occur during gift wrapping
    public enum GiftWrapError: LocalizedError {
        case invalidEvent
        case signingFailed
        case encryptionFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidEvent:
                return "Invalid event for gift wrapping"
            case .signingFailed:
                return "Failed to sign event"
            case .encryptionFailed:
                return "Failed to encrypt event"
            }
        }
    }
    
    /// Create a seal (kind 13) event
    /// - Parameters:
    ///   - event: The rumor event to seal
    ///   - senderKeyPair: The sender's key pair
    ///   - recipientPublicKey: The recipient's public key
    /// - Returns: The sealed event
    public static func createSeal(
        rumor event: NostrEvent,
        senderKeyPair: KeyPair,
        recipientPublicKey: String
    ) throws -> NostrEvent {
        // Ensure the event is unsigned (a rumor)
        guard event.sig.isEmpty else {
            throw GiftWrapError.invalidEvent
        }
        
        // Serialize the rumor event
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let eventData = try encoder.encode(event)
        let eventJSON = String(data: eventData, encoding: .utf8)!
        
        // Encrypt the rumor using NIP-44
        let encryptedContent = try NIP44.encrypt(
            plaintext: eventJSON,
            senderPrivateKey: senderKeyPair.privateKey,
            recipientPublicKey: recipientPublicKey
        )
        
        // Create seal event with randomized timestamp
        let sealEvent = NostrEvent(
            pubkey: senderKeyPair.publicKey,
            createdAt: randomizedTimestamp(),
            kind: EventKind.seal,
            tags: [], // No tags in seal
            content: encryptedContent
        )
        
        // Sign the seal
        let signedSeal = try senderKeyPair.signEvent(sealEvent)
        
        return signedSeal
    }
    
    /// Create a gift wrap (kind 1059) event
    /// - Parameters:
    ///   - seal: The sealed event to wrap
    ///   - recipientPublicKey: The recipient's public key
    ///   - expirationTime: Optional expiration timestamp for disappearing messages
    /// - Returns: The gift wrapped event
    public static func createGiftWrap(
        seal: NostrEvent,
        recipientPublicKey: String,
        relayUrl: String? = nil,
        expirationTime: Int64? = nil
    ) throws -> NostrEvent {
        // Generate random key pair for gift wrap
        let randomKeyPair = try generateRandomKeyPair()
        
        // Serialize the seal event
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let sealData = try encoder.encode(seal)
        let sealJSON = String(data: sealData, encoding: .utf8)!
        
        // Encrypt the seal using NIP-44 with random key
        let encryptedContent = try NIP44.encrypt(
            plaintext: sealJSON,
            senderPrivateKey: randomKeyPair.privateKey,
            recipientPublicKey: recipientPublicKey
        )
        
        // Create tags
        var tags: [[String]] = []
        
        // Add p tag for recipient
        if let relayUrl = relayUrl {
            tags.append(["p", recipientPublicKey, relayUrl])
        } else {
            tags.append(["p", recipientPublicKey])
        }
        
        // Add expiration tag if specified
        if let expirationTime = expirationTime {
            tags.append(["expiration", String(expirationTime)])
        }
        
        // Create gift wrap event with randomized timestamp
        let giftWrap = NostrEvent(
            pubkey: randomKeyPair.publicKey,
            createdAt: randomizedTimestamp(),
            kind: EventKind.giftWrap,
            tags: tags,
            content: encryptedContent
        )
        
        // Sign with random key
        let signedGiftWrap = try randomKeyPair.signEvent(giftWrap)
        
        return signedGiftWrap
    }
    
    /// Unwrap a gift wrap event
    /// - Parameters:
    ///   - giftWrap: The gift wrap event
    ///   - recipientKeyPair: The recipient's key pair
    /// - Returns: The unwrapped seal event
    public static func unwrapGift(
        _ giftWrap: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> NostrEvent {
        // Verify this is a gift wrap event
        guard giftWrap.kind == EventKind.giftWrap else {
            throw GiftWrapError.invalidEvent
        }
        
        // Decrypt the content using the gift wrap's pubkey
        let decryptedContent = try NIP44.decrypt(
            payload: giftWrap.content,
            recipientPrivateKey: recipientKeyPair.privateKey,
            senderPublicKey: giftWrap.pubkey
        )
        
        // Parse the seal event
        guard let sealData = decryptedContent.data(using: .utf8) else {
            throw GiftWrapError.invalidEvent
        }
        
        let decoder = JSONDecoder()
        let seal = try decoder.decode(NostrEvent.self, from: sealData)
        
        // Verify it's a seal event
        guard seal.kind == EventKind.seal else {
            throw GiftWrapError.invalidEvent
        }
        
        return seal
    }
    
    /// Open a seal event
    /// - Parameters:
    ///   - seal: The seal event
    ///   - recipientKeyPair: The recipient's key pair
    /// - Returns: The original rumor event
    public static func openSeal(
        _ seal: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> NostrEvent {
        // Verify this is a seal event
        guard seal.kind == EventKind.seal else {
            throw GiftWrapError.invalidEvent
        }
        
        // Decrypt the content using the seal's pubkey (sender)
        let decryptedContent = try NIP44.decrypt(
            payload: seal.content,
            recipientPrivateKey: recipientKeyPair.privateKey,
            senderPublicKey: seal.pubkey
        )
        
        // Parse the rumor event
        guard let rumorData = decryptedContent.data(using: .utf8) else {
            throw GiftWrapError.invalidEvent
        }
        
        let decoder = JSONDecoder()
        let rumor = try decoder.decode(NostrEvent.self, from: rumorData)
        
        return rumor
    }
    
    /// Convenience method to unwrap and open a gift wrap in one step
    /// - Parameters:
    ///   - giftWrap: The gift wrap event
    ///   - recipientKeyPair: The recipient's key pair
    /// - Returns: The original rumor event and the seal
    public static func unwrapAndOpen(
        _ giftWrap: NostrEvent,
        recipientKeyPair: KeyPair
    ) throws -> (rumor: NostrEvent, seal: NostrEvent) {
        let seal = try unwrapGift(giftWrap, recipientKeyPair: recipientKeyPair)
        let rumor = try openSeal(seal, recipientKeyPair: recipientKeyPair)
        return (rumor, seal)
    }
    
    /// Generate a randomized timestamp up to 2 days in the past
    private static func randomizedTimestamp() -> Date {
        let now = Date()
        let twoDaysInSeconds: TimeInterval = 2 * 24 * 60 * 60
        let randomOffset = TimeInterval.random(in: 0...twoDaysInSeconds)
        return now.addingTimeInterval(-randomOffset)
    }
    
    /// Generate a random key pair for gift wrapping
    private static func generateRandomKeyPair() throws -> KeyPair {
        // Generate random 32 bytes for private key
        var privateKeyData = Data(count: 32)
        let result = privateKeyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw GiftWrapError.encryptionFailed
        }
        
        return try KeyPair(privateKey: privateKeyData.hex)
    }
}

// MARK: - EventKind Constants

extension EventKind {
    /// Seal event (NIP-59)
    public static let seal = 13
    
    /// Gift wrap event (NIP-59)
    public static let giftWrap = 1059
}