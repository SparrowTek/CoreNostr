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
}