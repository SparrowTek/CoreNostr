//
//  NostrDirectMessage.swift
//  CoreNostr
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Foundation

/// A NOSTR encrypted direct message implementing NIP-04 specification.
///
/// **Security Warning**: NIP-04 is deprecated in favor of NIP-17 due to security
/// concerns. This implementation is provided for backward compatibility only.
/// 
/// Direct messages are encrypted using AES-256-CBC with a shared secret derived
/// from ECDH between the sender's private key and recipient's public key.
///
/// ## Example
/// ```swift
/// let directMessage = try NostrDirectMessage.create(
///     senderKeyPair: senderKeyPair,
///     recipientPublicKey: recipientPubkey,
///     message: "Hello, this is a private message!",
///     replyTo: nil
/// )
/// 
/// let event = directMessage.createEvent(pubkey: senderKeyPair.publicKey)
/// ```
///
/// ## Security Considerations
/// - This standard leaks metadata in events
/// - Should only be used with relays that use AUTH to restrict access
/// - Not recommended for sensitive communications
/// - Clients should not process content like regular text notes to avoid tag leakage
public struct NostrDirectMessage: Codable, Hashable, Sendable {
    /// The recipient's public key
    public let recipientPublicKey: PublicKey
    
    /// Optional event ID this message is replying to
    public let replyToEventId: EventID?
    
    /// The encrypted message content in format "encrypted?iv=base64_iv"
    public let encryptedContent: String
    
    /// Creates a new encrypted direct message.
    ///
    /// - Parameters:
    ///   - recipientPublicKey: The recipient's public key
    ///   - replyToEventId: Optional event ID this message is replying to
    ///   - encryptedContent: The encrypted content in NIP-04 format
    public init(recipientPublicKey: PublicKey, replyToEventId: EventID? = nil, encryptedContent: String) {
        self.recipientPublicKey = recipientPublicKey
        self.replyToEventId = replyToEventId
        self.encryptedContent = encryptedContent
    }
    
    /// Creates an encrypted direct message from a plaintext message.
    ///
    /// - Parameters:
    ///   - senderKeyPair: The sender's key pair for encryption
    ///   - recipientPublicKey: The recipient's public key
    ///   - message: The plaintext message to encrypt
    ///   - replyToEventId: Optional event ID this message is replying to
    /// - Returns: An encrypted direct message
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if encryption fails
    public static func create(
        senderKeyPair: KeyPair,
        recipientPublicKey: PublicKey,
        message: String,
        replyToEventId: EventID? = nil
    ) throws -> NostrDirectMessage {
        let sharedSecret = try senderKeyPair.getSharedSecret(with: recipientPublicKey)
        let encryptedContent = try NostrCrypto.encryptMessage(message, with: sharedSecret)
        
        return NostrDirectMessage(
            recipientPublicKey: recipientPublicKey,
            replyToEventId: replyToEventId,
            encryptedContent: encryptedContent
        )
    }
    
    /// Creates a direct message from a NostrEvent.
    ///
    /// - Parameter event: The event to parse (must be kind 4)
    /// - Returns: A direct message if the event is valid, nil otherwise
    public static func from(event: NostrEvent) -> NostrDirectMessage? {
        guard event.kind == EventKind.encryptedDirectMessage.rawValue else {
            return nil
        }
        
        // Find the "p" tag containing the recipient's public key
        guard let recipientTag = event.tags.first(where: { $0.count >= 2 && $0[0] == "p" }),
              !recipientTag[1].isEmpty else {
            return nil
        }
        
        let recipientPublicKey = recipientTag[1]
        
        // Find optional "e" tag for reply
        let replyToEventId = event.tags.first { $0.count >= 2 && $0[0] == "e" }?[1]
        
        return NostrDirectMessage(
            recipientPublicKey: recipientPublicKey,
            replyToEventId: replyToEventId,
            encryptedContent: event.content
        )
    }
    
    /// Creates a NostrEvent from this direct message.
    ///
    /// - Parameters:
    ///   - pubkey: The sender's public key
    ///   - createdAt: Creation timestamp (defaults to current time)
    /// - Returns: An unsigned NostrEvent ready for signing
    public func createEvent(pubkey: PublicKey, createdAt: Date = Date()) -> NostrEvent {
        var tags: [[String]] = []
        
        // Add the recipient tag (required)
        tags.append(["p", recipientPublicKey])
        
        // Add reply tag if this is a reply
        if let replyToEventId = replyToEventId {
            tags.append(["e", replyToEventId])
        }
        
        return NostrEvent(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: EventKind.encryptedDirectMessage.rawValue,
            tags: tags,
            content: encryptedContent
        )
    }
    
    /// Decrypts the message content using the recipient's key pair.
    ///
    /// - Parameters:
    ///   - recipientKeyPair: The recipient's key pair for decryption
    ///   - senderPublicKey: The sender's public key
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if decryption fails
    public func decrypt(with recipientKeyPair: KeyPair, senderPublicKey: PublicKey) throws -> String {
        let sharedSecret = try recipientKeyPair.getSharedSecret(with: senderPublicKey)
        return try NostrCrypto.decryptMessage(encryptedContent, with: sharedSecret)
    }
    
    /// Validates the encrypted content format.
    ///
    /// - Returns: True if the content follows the NIP-04 format "encrypted?iv=base64_iv"
    public func isValidEncryptedContent() -> Bool {
        let components = encryptedContent.split(separator: "?", maxSplits: 1)
        guard components.count == 2,
              let ivParam = components[1].split(separator: "=", maxSplits: 1).last else {
            return false
        }
        
        let encryptedBase64 = String(components[0])
        let ivBase64 = String(ivParam)
        
        return Data(base64Encoded: encryptedBase64) != nil &&
               Data(base64Encoded: ivBase64) != nil
    }
    
    /// Gets the size of the encrypted content in bytes (before base64 encoding).
    ///
    /// - Returns: The approximate size of the encrypted data, or nil if invalid format
    public var encryptedDataSize: Int? {
        let components = encryptedContent.split(separator: "?", maxSplits: 1)
        guard components.count == 2,
              let encryptedData = Data(base64Encoded: String(components[0])) else {
            return nil
        }
        return encryptedData.count
    }
    
    /// Whether this message is a reply to another message.
    public var isReply: Bool {
        return replyToEventId != nil
    }
}

// MARK: - Security Warning Extension

extension NostrDirectMessage {
    /// Security warning about NIP-04 usage.
    ///
    /// This property serves as a reminder of the security limitations of NIP-04.
    public static var securityWarning: String {
        """
        ⚠️ SECURITY WARNING: NIP-04 encrypted direct messages are DEPRECATED.
        
        This implementation has known security issues:
        • Metadata leaks in events
        • Not state-of-the-art encryption
        • Should only be used with AUTH-enabled relays
        • Not suitable for sensitive communications
        
        Use NIP-17 (Private Direct Messages) for new implementations.
        This is provided for backward compatibility only.
        """
    }
}