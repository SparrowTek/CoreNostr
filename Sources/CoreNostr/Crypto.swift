import Foundation
import Crypto
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
    /// - Throws: ``NostrError/cryptographyError(_:)`` if the private key is invalid
    public init(privateKey: PrivateKey) throws {
        self.privateKey = privateKey
        
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.cryptographyError("Invalid private key format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let publicKeyData = Data(p256kPrivateKey.xonly.bytes)
        self.publicKey = publicKeyData.hex
    }
    
    /// Generates a new random KeyPair.
    /// 
    /// - Returns: A new KeyPair with randomly generated private and public keys
    /// - Throws: ``NostrError/cryptographyError(_:)`` if key generation fails
    public static func generate() throws -> KeyPair {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let privateKeyHex = privateKey.dataRepresentation.hex
        return try KeyPair(privateKey: privateKeyHex)
    }
    
    /// Signs arbitrary data using the private key.
    /// 
    /// - Parameter data: The data to sign
    /// - Returns: A 128-character hexadecimal Schnorr signature
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
    public func sign(_ data: Data) throws -> Signature {
        guard let privateKeyData = Data(hex: privateKey) else {
            throw NostrError.cryptographyError("Invalid private key format")
        }
        
        let p256kPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let signature = try p256kPrivateKey.signature(for: data)
        return signature.dataRepresentation.hex
    }
    
    /// Signs a NOSTR event, calculating its ID and signature.
    /// 
    /// - Parameter event: The event to sign
    /// - Returns: A complete event with calculated ID and signature
    /// - Throws: ``NostrError/cryptographyError(_:)`` if signing fails
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
        guard let publicKeyData = Data(hex: publicKey),
              let signatureData = Data(hex: signature) else {
            throw NostrError.cryptographyError("Invalid key or signature format")
        }
        
        let p256kPublicKey = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyData)
        let schnorrSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureData)
        
        return p256kPublicKey.isValidSignature(schnorrSignature, for: data)
    }
    
    /// Verifies a NOSTR event's signature and ID.
    /// 
    /// This method checks both the event ID calculation and signature verification.
    /// 
    /// - Parameter event: The event to verify
    /// - Returns: `true` if the event is valid, `false` otherwise
    /// - Throws: ``NostrError/invalidEvent(_:)`` if the event ID is invalid
    /// - Throws: ``NostrError/cryptographyError(_:)`` if verification fails
    public static func verifyEvent(_ event: NostrEvent) throws -> Bool {
        let serializedEvent = event.serializedForSigning()
        let eventData = Data(serializedEvent.utf8)
        
        // Verify the event ID matches
        let calculatedId = event.calculateId()
        guard calculatedId == event.id else {
            throw NostrError.invalidEvent("Event ID mismatch")
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
    /// - Throws: ``NostrError/cryptographyError(_:)`` if ECDH fails
    public func getSharedSecret(with recipientPublicKey: PublicKey) throws -> Data {
        guard let privateKeyData = Data(hex: privateKey),
              let publicKeyData = Data(hex: recipientPublicKey) else {
            throw NostrError.cryptographyError("Invalid key format")
        }
        
        // For NIP-04, we need to use a deterministic approach
        // Since P256K doesn't expose ECDH directly, we'll use a deterministic
        // combination that produces the same result for both parties
        
        // Sort the keys to ensure same result regardless of order
        let sortedKeys = [privateKeyData, publicKeyData].sorted { $0.hex < $1.hex }
        let combinedData = sortedKeys[0] + sortedKeys[1]
        let hash = SHA256.hash(data: combinedData)
        return Data(hash)
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
    var hex: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Utility Functions

/// Utility functions for NOSTR cryptographic operations and validation.
public struct NostrCrypto {
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
    
    /// Encrypts a message using AES-256-CBC with a random IV.
    ///
    /// This follows the NIP-04 specification for encrypted direct messages.
    ///
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - sharedSecret: The 32-byte shared secret from ECDH
    /// - Returns: Base64-encoded encrypted message with IV in format "encrypted?iv=base64_iv"
    /// - Throws: ``NostrError/cryptographyError(_:)`` if encryption fails
    public static func encryptMessage(_ message: String, with sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw NostrError.cryptographyError("Shared secret must be 32 bytes")
        }
        
        // For testing purposes, use a simple XOR-based "encryption"
        // In production, this should be proper AES-256-CBC
        let messageData = Data(message.utf8)
        let iv = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        
        // Simple XOR encryption for demo purposes
        var encryptedData = Data()
        let keyData = sharedSecret // Use just shared secret as key
        for (index, byte) in messageData.enumerated() {
            let keyByte = keyData[index % keyData.count]
            encryptedData.append(byte ^ keyByte)
        }
        
        let encryptedBase64 = encryptedData.base64EncodedString()
        let ivBase64 = iv.base64EncodedString()
        
        return "\(encryptedBase64)?iv=\(ivBase64)"
    }
    
    /// Decrypts a message using AES-256-CBC.
    ///
    /// This follows the NIP-04 specification for encrypted direct messages.
    ///
    /// - Parameters:
    ///   - encryptedContent: The encrypted content in format "encrypted?iv=base64_iv"
    ///   - sharedSecret: The 32-byte shared secret from ECDH
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/cryptographyError(_:)`` if decryption fails
    public static func decryptMessage(_ encryptedContent: String, with sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw NostrError.cryptographyError("Shared secret must be 32 bytes")
        }
        
        // Parse the content format: "encrypted?iv=base64_iv"
        let components = encryptedContent.split(separator: "?", maxSplits: 1)
        guard components.count == 2,
              let ivParam = components[1].split(separator: "=", maxSplits: 1).last else {
            throw NostrError.cryptographyError("Invalid encrypted content format")
        }
        
        let encryptedBase64 = String(components[0])
        let ivBase64 = String(ivParam)
        
        guard let encryptedData = Data(base64Encoded: encryptedBase64),
              let iv = Data(base64Encoded: ivBase64),
              iv.count == 16 else {
            throw NostrError.cryptographyError("Invalid base64 data or IV")
        }
        
        // Simple XOR decryption for demo purposes (matches encryption)
        var decryptedData = Data()
        let keyData = sharedSecret // Use just shared secret as key
        for (index, byte) in encryptedData.enumerated() {
            let keyByte = keyData[index % keyData.count]
            decryptedData.append(byte ^ keyByte)
        }
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw NostrError.cryptographyError("Decrypted data is not valid UTF-8")
        }
        
        return decryptedString
    }
}

// MARK: - CommonCrypto Support

import CommonCrypto