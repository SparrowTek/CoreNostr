import Foundation
import Crypto
import CryptoKit
import P256K

// MARK: - KeyPair

/// A secp256k1 key pair for NOSTR operations.
/// 
/// KeyPair manages both private and public keys, providing methods for
/// key generation, event signing, and signature verification.
/// 
/// ## Example
/// ```swift
/// // Generate a new key pair
/// let keyPair = try KeyPair.generate()
/// 
/// // Sign an event
/// let signedEvent = try keyPair.signEvent(event)
/// 
/// // Verify an event
/// let isValid = try KeyPair.verifyEvent(signedEvent)
/// ```
/// 
/// - Note: Private keys should be kept secure and never transmitted or logged.
public struct KeyPair: Sendable, Codable {
    /// The private key in hexadecimal format (64 characters).
    /// 
    /// - Important: Keep this value secure and never share it.
    public let privateKey: PrivateKey
    
    /// The corresponding public key in hexadecimal format (64 characters).
    /// 
    /// This serves as the user's identity in the NOSTR protocol.
    public let publicKey: PublicKey
    
    /// Creates a KeyPair from an existing private key.
    /// 
    /// - Parameter privateKey: A 64-character hexadecimal private key
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if the private key is invalid
    public init(privateKey: PrivateKey) throws {
        try Validation.validatePrivateKey(privateKey)
        self.privateKey = privateKey
        
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.invalidPrivateKey(reason: "Invalid hexadecimal format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let publicKeyData = Data(p256kPrivateKey.xonly.bytes)
        self.publicKey = publicKeyData.hex
    }
    
    /// Generates a new random KeyPair.
    /// 
    /// - Returns: A new KeyPair with randomly generated private and public keys
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if key generation fails
    public static func generate() throws -> KeyPair {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let privateKeyHex = privateKey.dataRepresentation.hex
        return try KeyPair(privateKey: privateKeyHex)
    }
    
    /// Signs arbitrary data using the private key.
    /// 
    /// - Parameter data: The data to sign
    /// - Returns: A 128-character hexadecimal Schnorr signature
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if signing fails
    public func sign(_ data: Data) throws -> Signature {
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.invalidPrivateKey(reason: "Invalid hexadecimal format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let digest = SHA256.hash(data: data)
        let signature = try p256kPrivateKey.signature(for: digest)
        return signature.dataRepresentation.hex
    }
    
    /// Signs a NOSTR event, calculating its ID and signature.
    /// 
    /// - Parameter event: The event to sign
    /// - Returns: A complete event with calculated ID and signature
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if signing fails
    public func signEvent(_ event: NostrEvent) throws -> NostrEvent {
        let serializedEvent = event.serializedForSigning()
        let eventData = Data(serializedEvent.utf8)
        let signature = try sign(eventData)
        return event.withSignature(signature)
    }
    
    /// Verifies a signature against data using a public key.
    /// 
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The original data that was signed
    ///   - publicKey: The public key to verify against
    /// - Returns: `true` if the signature is valid, `false` otherwise
    /// - Throws: ``NostrError/cryptographyError(_:)`` if verification fails
    public static func verify(signature: Signature, data: Data, publicKey: PublicKey) throws -> Bool {
        try Validation.validatePublicKey(publicKey)
        try Validation.validateSignature(signature)
        
        guard let publicKeyData = Data(hex: publicKey),
              let signatureData = Data(hex: signature) else {
            throw NostrError.cryptographyError(operation: .verification, reason: "Invalid hexadecimal format for key or signature")
        }
        
        let p256kPublicKey = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyData)
        let schnorrSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureData)
        
        let digest = SHA256.hash(data: data)
        return p256kPublicKey.isValidSignature(schnorrSignature, for: digest)
    }
    
    /// Verifies a NOSTR event's signature and ID.
    /// 
    /// This method checks both the event ID calculation and signature verification.
    /// 
    /// - Parameter event: The event to verify
    /// - Returns: `true` if the event is valid, `false` otherwise
    /// - Throws: ``NostrError/invalidEvent(reason:)`` if the event ID is invalid
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if verification fails
    public static func verifyEvent(_ event: NostrEvent) throws -> Bool {
        let serializedEvent = event.serializedForSigning()
        let eventData = Data(serializedEvent.utf8)
        
        // Verify the event ID matches using constant-time comparison
        let calculatedId = event.calculateId()
        guard Security.constantTimeHexCompare(calculatedId, event.id) else {
            // Don't reveal the actual values in the error for security
            throw NostrError.invalidEventId(expected: "[REDACTED]", actual: "[REDACTED]")
        }
        
        // Verify the signature
        return try verify(signature: event.sig, data: eventData, publicKey: event.pubkey)
    }
    
    /// Generates a shared secret for encryption using ECDH.
    ///
    /// This follows the NIP-04 specification where only the X coordinate
    /// of the shared point is used as the secret (not hashed).
    ///
    /// - Parameter recipientPublicKey: The recipient's public key
    /// - Returns: 32-byte shared secret for AES encryption
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if ECDH fails
    public func getSharedSecret(with recipientPublicKey: PublicKey) throws -> Data {
        try NostrCrypto.ecdhSharedSecret(
            privateKeyHex: privateKey,
            publicKeyHex: recipientPublicKey
        )
    }
    
    /// Encrypts a message to a recipient using NIP-04 encryption.
    /// 
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - recipientPublicKey: The recipient's public key
    /// - Returns: Base64-encoded encrypted message with IV in format "encrypted?iv=base64_iv"
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if encryption fails
    public func encrypt(message: String, to recipientPublicKey: PublicKey) throws -> String {
        let sharedSecret = try getSharedSecret(with: recipientPublicKey)
        return try NostrCrypto.encryptMessage(message, with: sharedSecret)
    }
    
    /// Decrypts a message from a sender using NIP-04 decryption.
    /// 
    /// - Parameters:
    ///   - encryptedContent: The encrypted content in format "encrypted?iv=base64_iv"
    ///   - senderPublicKey: The sender's public key
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if decryption fails
    public func decrypt(message encryptedContent: String, from senderPublicKey: PublicKey) throws -> String {
        let sharedSecret = try getSharedSecret(with: senderPublicKey)
        return try NostrCrypto.decryptMessage(encryptedContent, with: sharedSecret)
    }
    
    /// Encrypts a message using NIP-44 encryption.
    ///
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - recipientPublicKey: The recipient's public key
    /// - Returns: Base64-encoded encrypted payload
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if encryption fails
    public func encryptNIP44(message: String, to recipientPublicKey: PublicKey) throws -> String {
        return try NIP44.encrypt(
            plaintext: message,
            senderPrivateKey: privateKey,
            recipientPublicKey: recipientPublicKey
        )
    }
    
    /// Decrypts a message using NIP-44 decryption.
    ///
    /// - Parameters:
    ///   - payload: Base64-encoded encrypted payload
    ///   - senderPublicKey: The sender's public key
    /// - Returns: Decrypted plaintext message
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if decryption fails
    public func decryptNIP44(payload: String, from senderPublicKey: PublicKey) throws -> String {
        return try NIP44.decrypt(
            payload: payload,
            recipientPrivateKey: privateKey,
            senderPublicKey: senderPublicKey
        )
    }
}

// MARK: - Data Extensions

/// Extensions for Data to support hexadecimal encoding and decoding.
extension Data {
    /// Creates Data from a hexadecimal string.
    /// 
    /// - Parameter hex: A hexadecimal string (with or without spaces)
    /// - Returns: Data representation, or `nil` if the string is invalid
    init?(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: cleanHex.count / 2)
        var index = cleanHex.startIndex
        
        for _ in 0..<cleanHex.count / 2 {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Converts Data to a hexadecimal string representation.
    ///
    /// - Returns: Lowercase hexadecimal string
    public var hex: String {
        // Hot path (every event id, pubkey, signature). Per-byte String(format:)
        // allocates a temporary per byte; a single-pass table lookup into a
        // preallocated byte buffer is ~5-10× faster.
        let table: [UInt8] = [
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66
        ] // "0123456789abcdef"
        var out = [UInt8](repeating: 0, count: count * 2)
        for (i, byte) in enumerated() {
            out[i &* 2]     = table[Int(byte >> 4)]
            out[i &* 2 &+ 1] = table[Int(byte & 0x0f)]
        }
        return String(decoding: out, as: UTF8.self)
    }
}

// MARK: - Utility Functions

/// Utility functions for NOSTR cryptographic operations and validation.
public struct NostrCrypto: Sendable {
    /// Generates an event ID for the given event.
    /// 
    /// - Parameter event: The event to generate an ID for
    /// - Returns: A 64-character hexadecimal event ID
    public static func generateEventId(for event: NostrEvent) -> EventID {
        return event.calculateId()
    }
    
    /// Validates whether a string is a valid event ID.
    /// 
    /// - Parameter id: The event ID to validate
    /// - Returns: `true` if the ID is a valid 64-character hexadecimal string
    public static func isValidEventId(_ id: EventID) -> Bool {
        return id.count == 64 && id.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates whether a string is a valid public key.
    /// 
    /// - Parameter key: The public key to validate
    /// - Returns: `true` if the key is a valid 64-character hexadecimal string
    public static func isValidPublicKey(_ key: PublicKey) -> Bool {
        return key.count == 64 && key.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates whether a string is a valid private key.
    /// 
    /// - Parameter key: The private key to validate
    /// - Returns: `true` if the key is a valid 64-character hexadecimal string
    public static func isValidPrivateKey(_ key: PrivateKey) -> Bool {
        return key.count == 64 && key.allSatisfy { $0.isHexDigit }
    }
    
    /// Validates whether a string is a valid signature.
    ///
    /// - Parameter signature: The signature to validate
    /// - Returns: `true` if the signature is a valid 128-character hexadecimal string
    public static func isValidSignature(_ signature: Signature) -> Bool {
        return signature.count == 128 && signature.allSatisfy { $0.isHexDigit }
    }
}
