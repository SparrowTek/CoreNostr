import Foundation
import Crypto
import CryptoKit
import P256K

// MARK: - ECDH Shared Secret and NIP-04 Encryption

public extension NostrCrypto {

    /// Computes the raw ECDH shared secret (x-coordinate) between a hex-encoded
    /// private key and a hex-encoded x-only public key.
    ///
    /// Both NIP-04 and NIP-44 use this same primitive. NIP-04 uses the 32-byte
    /// result directly as the AES key; NIP-44 feeds it into HKDF-extract as IKM.
    ///
    /// Because NOSTR public keys are x-only (NIP-01), the full point is recovered
    /// by trying the even y-parity (`0x02` prefix) first, then falling back to
    /// odd (`0x03`). Some P256K builds return the shared secret already as the
    /// raw x-coordinate (32 bytes); others return compressed (33 bytes) or
    /// uncompressed (64 bytes, x || y). We normalize to the 32-byte x-coordinate.
    ///
    /// - Parameters:
    ///   - privateKeyHex: 64-character hex private key
    ///   - publicKeyHex: 64-character hex x-only public key
    /// - Returns: 32-byte x-coordinate of the shared point
    /// - Throws: `NostrError.encryptionError(operation: .keyExchange, ...)` on
    ///   bad input or ECDH failure
    internal static func ecdhSharedSecret(
        privateKeyHex: String,
        publicKeyHex: String
    ) throws -> Data {
        guard let privateKeyData = Data(hex: privateKeyHex),
              privateKeyData.count == 32 else {
            throw NostrError.encryptionError(operation: .keyExchange, reason: "Invalid private key")
        }
        guard let publicKeyData = Data(hex: publicKeyHex),
              publicKeyData.count == 32 else {
            throw NostrError.encryptionError(operation: .keyExchange, reason: "Invalid public key")
        }

        let p256kPrivateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKeyData)

        // x-only: try even y-parity first, fall back to odd.
        var compressedPubKey = Data([0x02]) + publicKeyData
        let p256kPublicKey: P256K.KeyAgreement.PublicKey
        do {
            p256kPublicKey = try P256K.KeyAgreement.PublicKey(dataRepresentation: compressedPubKey)
        } catch {
            compressedPubKey[0] = 0x03
            p256kPublicKey = try P256K.KeyAgreement.PublicKey(dataRepresentation: compressedPubKey)
        }

        let sharedSecret = try p256kPrivateKey.sharedSecretFromKeyAgreement(with: p256kPublicKey)
        let bytes = Data(sharedSecret.bytes)

        switch bytes.count {
        case 32:
            return bytes
        case 33:
            // Compressed point (0x02/0x03 || x) — drop the parity byte.
            return Data(bytes[1..<33])
        case 64:
            // Uncompressed point (x || y) — first 32 bytes are the x-coordinate.
            return Data(bytes[0..<32])
        default:
            throw NostrError.encryptionError(
                operation: .keyExchange,
                reason: "Unexpected shared secret size: \(bytes.count) bytes"
            )
        }
    }

    /// Encrypts a message using AES-256-CBC with a random IV.
    ///
    /// This follows the NIP-04 specification for encrypted direct messages.
    ///
    /// - Parameters:
    ///   - message: The plaintext message to encrypt
    ///   - sharedSecret: The 32-byte shared secret from ECDH
    /// - Returns: Base64-encoded encrypted message with IV in format "encrypted?iv=base64_iv"
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if encryption fails
    static func encryptMessage(_ message: String, with sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw NostrError.encryptionError(operation: .encrypt, reason: "Shared secret must be 32 bytes, got \(sharedSecret.count)")
        }

        // NIP-04 specifies AES-256-CBC encryption
        let messageData = Data(message.utf8)
        let iv = Data((0..<16).map { _ in UInt8.random(in: 0...255) })

        do {
            // Use AES-256-CBC encryption with PKCS7 padding
            let encryptedData = try AES256CBC.encrypt(data: messageData, key: sharedSecret, iv: iv)

            let encryptedBase64 = encryptedData.base64EncodedString()
            let ivBase64 = iv.base64EncodedString()

            return "\(encryptedBase64)?iv=\(ivBase64)"
        } catch {
            throw NostrError.encryptionError(operation: .encrypt, reason: "AES-256-CBC encryption failed: \(error.localizedDescription)")
        }
    }

    /// Decrypts a message using AES-256-CBC.
    ///
    /// This follows the NIP-04 specification for encrypted direct messages.
    ///
    /// - Parameters:
    ///   - encryptedContent: The encrypted content in format "encrypted?iv=base64_iv"
    ///   - sharedSecret: The 32-byte shared secret from ECDH
    /// - Returns: The decrypted plaintext message
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if decryption fails
    static func decryptMessage(_ encryptedContent: String, with sharedSecret: Data) throws -> String {
        guard sharedSecret.count == 32 else {
            throw NostrError.encryptionError(operation: .decrypt, reason: "Shared secret must be 32 bytes, got \(sharedSecret.count)")
        }

        // Parse the content format: "encrypted?iv=base64_iv"
        let components = encryptedContent.split(separator: "?", maxSplits: 1)
        guard components.count == 2,
              let ivParam = components[1].split(separator: "=", maxSplits: 1).last else {
            throw NostrError.encryptionError(operation: .decrypt, reason: "Invalid encrypted content format. Expected 'encrypted?iv=base64_iv'")
        }

        let encryptedBase64 = String(components[0])
        let ivBase64 = String(ivParam)

        guard let encryptedData = Data(base64Encoded: encryptedBase64),
              let iv = Data(base64Encoded: ivBase64),
              iv.count == 16 else {
            throw NostrError.encryptionError(operation: .decrypt, reason: "Invalid base64 encoding or IV must be 16 bytes")
        }

        do {
            // Use AES-256-CBC decryption with PKCS7 padding
            let decryptedData = try AES256CBC.decrypt(data: encryptedData, key: sharedSecret, iv: iv)

            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw NostrError.encryptionError(operation: .decrypt, reason: "Decrypted data is not valid UTF-8 text")
            }

            return decryptedString
        } catch {
            throw NostrError.encryptionError(operation: .decrypt, reason: "AES-256-CBC decryption failed: \(error.localizedDescription)")
        }
    }
}
