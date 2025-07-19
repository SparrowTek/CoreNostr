//
//  NIP44.swift
//  CoreNostr
//
//  NIP-44: Encrypted Payloads
//  https://github.com/nostr-protocol/nips/blob/master/44.md
//
//  IMPORTANT: This implementation currently uses a placeholder for ECDH
//  shared secret computation. Proper secp256k1 ECDH implementation is
//  required for production use. The current implementation will not
//  interoperate with other NIP-44 implementations.
//

import Foundation
import CryptoKit

/// NIP-44 Encrypted Payloads
public enum NIP44 {
    
    /// Errors that can occur during encryption/decryption
    public enum NIP44Error: LocalizedError {
        case invalidPublicKey
        case invalidPrivateKey
        case invalidPayload
        case invalidVersion
        case invalidPadding
        case decryptionFailed
        case encryptionFailed
        case hmacVerificationFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidPublicKey:
                return "Invalid public key"
            case .invalidPrivateKey:
                return "Invalid private key"
            case .invalidPayload:
                return "Invalid payload format"
            case .invalidVersion:
                return "Unsupported encryption version"
            case .invalidPadding:
                return "Invalid padding"
            case .decryptionFailed:
                return "Decryption failed"
            case .encryptionFailed:
                return "Encryption failed"
            case .hmacVerificationFailed:
                return "HMAC verification failed"
            }
        }
    }
    
    /// Current version of the encryption scheme
    private static let version: UInt8 = 2
    
    /// Minimum plaintext size
    private static let minPlaintextSize = 1
    
    /// Maximum plaintext size (64KB - 1)
    private static let maxPlaintextSize = 65535
    
    /// Encrypt a message using NIP-44 specification
    /// - Parameters:
    ///   - plaintext: The message to encrypt
    ///   - senderPrivateKey: Sender's private key
    ///   - recipientPublicKey: Recipient's public key
    /// - Returns: Base64-encoded encrypted payload
    public static func encrypt(
        plaintext: String,
        senderPrivateKey: String,
        recipientPublicKey: String
    ) throws -> String {
        // Validate inputs
        guard let plaintextData = plaintext.data(using: .utf8) else {
            throw NIP44Error.invalidPayload
        }
        
        guard plaintextData.count >= minPlaintextSize && plaintextData.count <= maxPlaintextSize else {
            throw NIP44Error.invalidPayload
        }
        
        // Get shared secret
        let sharedSecret = try computeSharedSecret(
            privateKey: senderPrivateKey,
            publicKey: recipientPublicKey
        )
        
        // Generate random nonce
        let nonce = generateNonce()
        
        // Derive keys
        let (encryptionKey, hmacKey) = try deriveKeys(
            sharedSecret: sharedSecret,
            nonce: nonce
        )
        
        // Pad plaintext
        let paddedPlaintext = pad(plaintextData)
        
        // Encrypt
        let ciphertext = try encryptChaCha20(
            plaintext: paddedPlaintext,
            key: encryptionKey,
            nonce: nonce
        )
        
        // Create payload
        var payload = Data()
        payload.append(version)
        payload.append(nonce)
        payload.append(ciphertext)
        
        // Compute HMAC
        let hmac = computeHMAC(payload: payload, key: hmacKey)
        payload.append(hmac)
        
        // Encode to base64
        return payload.base64EncodedString()
    }
    
    /// Decrypt a message using NIP-44 specification
    /// - Parameters:
    ///   - payload: Base64-encoded encrypted payload
    ///   - recipientPrivateKey: Recipient's private key
    ///   - senderPublicKey: Sender's public key
    /// - Returns: Decrypted plaintext message
    public static func decrypt(
        payload: String,
        recipientPrivateKey: String,
        senderPublicKey: String
    ) throws -> String {
        // Decode from base64
        guard let payloadData = Data(base64Encoded: payload) else {
            throw NIP44Error.invalidPayload
        }
        
        // Minimum size: version(1) + nonce(32) + ciphertext(>=17) + hmac(32) = 82
        guard payloadData.count >= 82 else {
            throw NIP44Error.invalidPayload
        }
        
        // Parse payload
        let version = payloadData[0]
        guard version == Self.version else {
            throw NIP44Error.invalidVersion
        }
        
        let nonce = payloadData[1..<33]
        let hmacStart = payloadData.count - 32
        let ciphertext = payloadData[33..<hmacStart]
        let receivedHMAC = payloadData[hmacStart...]
        
        // Get shared secret
        let sharedSecret = try computeSharedSecret(
            privateKey: recipientPrivateKey,
            publicKey: senderPublicKey
        )
        
        // Derive keys
        let (encryptionKey, hmacKey) = try deriveKeys(
            sharedSecret: sharedSecret,
            nonce: nonce
        )
        
        // Verify HMAC
        let payloadWithoutHMAC = payloadData[..<hmacStart]
        let computedHMAC = computeHMAC(payload: payloadWithoutHMAC, key: hmacKey)
        
        guard computedHMAC == receivedHMAC else {
            throw NIP44Error.hmacVerificationFailed
        }
        
        // Decrypt
        let paddedPlaintext = try decryptChaCha20(
            ciphertext: ciphertext,
            key: encryptionKey,
            nonce: nonce
        )
        
        // Unpad
        let plaintext = try unpad(paddedPlaintext)
        
        guard let result = String(data: plaintext, encoding: .utf8) else {
            throw NIP44Error.decryptionFailed
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Compute shared secret using ECDH
    private static func computeSharedSecret(
        privateKey: String,
        publicKey: String
    ) throws -> Data {
        // TODO: Implement proper ECDH using secp256k1
        // For now, use a placeholder that combines keys deterministically
        // This is NOT secure and must be replaced with proper ECDH
        
        guard let privKeyData = Data(hex: privateKey),
              let pubKeyData = Data(hex: publicKey) else {
            throw NIP44Error.invalidPrivateKey
        }
        
        // WARNING: This is a temporary placeholder - not secure!
        // Real implementation needs secp256k1 ECDH
        let combined = privKeyData + pubKeyData
        let hash = SHA256.hash(data: combined)
        return Data(hash)
    }
    
    /// Generate a random 32-byte nonce
    private static func generateNonce() -> Data {
        var nonce = Data(count: 32)
        _ = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return nonce
    }
    
    /// Derive encryption and HMAC keys from shared secret and nonce
    private static func deriveKeys(
        sharedSecret: Data,
        nonce: Data
    ) throws -> (encryptionKey: Data, hmacKey: Data) {
        // Combine shared secret and nonce
        var input = Data()
        input.append(sharedSecret)
        input.append(nonce)
        
        // Use HKDF to derive keys
        let salt = Data() // Empty salt
        let info = "nip44-v2".data(using: .utf8)!
        
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: input),
            salt: salt,
            info: info,
            outputByteCount: 76 // 32 for ChaCha20 + 12 for nonce expansion + 32 for HMAC
        )
        
        let keyData = derivedKey.withUnsafeBytes { Data($0) }
        
        let encryptionKey = keyData[0..<32]
        let hmacKey = keyData[44..<76]
        
        return (Data(encryptionKey), Data(hmacKey))
    }
    
    /// Encrypt using ChaCha20
    private static func encryptChaCha20(
        plaintext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        // ChaCha20 uses a 12-byte nonce, we use first 12 bytes of our 32-byte nonce
        let chachaNonceData = nonce[0..<12]
        
        guard let chachaNonce = try? ChaChaPoly.Nonce(data: chachaNonceData) else {
            throw NIP44Error.encryptionFailed
        }
        
        let sealedBox = try ChaChaPoly.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: chachaNonce
        )
        
        // Return only ciphertext (without auth tag for NIP-44)
        return sealedBox.ciphertext
    }
    
    /// Decrypt using ChaCha20
    private static func decryptChaCha20(
        ciphertext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        // ChaCha20 uses a 12-byte nonce
        let chachaNonceData = nonce[0..<12]
        
        guard let chachaNonce = try? ChaChaPoly.Nonce(data: chachaNonceData) else {
            throw NIP44Error.decryptionFailed
        }
        
        // Create a placeholder auth tag (16 bytes of zeros)
        let authTag = Data(repeating: 0, count: 16)
        
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: chachaNonce,
            ciphertext: ciphertext,
            tag: authTag
        )
        
        let plaintext = try ChaChaPoly.open(
            sealedBox,
            using: SymmetricKey(data: key)
        )
        
        return plaintext
    }
    
    /// Compute HMAC-SHA256
    private static func computeHMAC(payload: Data, key: Data) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(
            for: payload,
            using: SymmetricKey(data: key)
        )
        return Data(mac)
    }
    
    /// Pad plaintext according to NIP-44 specification
    private static func pad(_ plaintext: Data) -> Data {
        let unpaddedLen = plaintext.count
        
        var chunked = 32
        if unpaddedLen <= 32 {
            chunked = 32
        } else if unpaddedLen <= 96 {
            chunked = 96
        } else if unpaddedLen <= 224 {
            chunked = 224
        } else if unpaddedLen <= 480 {
            chunked = 480
        } else if unpaddedLen <= 992 {
            chunked = 992
        } else if unpaddedLen <= 2016 {
            chunked = 2016
        } else if unpaddedLen <= 4064 {
            chunked = 4064
        } else if unpaddedLen <= 8160 {
            chunked = 8160
        } else if unpaddedLen <= 16352 {
            chunked = 16352
        } else if unpaddedLen <= 32736 {
            chunked = 32736
        } else {
            chunked = 65536
        }
        
        let padded = chunked - unpaddedLen
        var result = plaintext
        result.append(Data(repeating: 0, count: padded))
        return result
    }
    
    /// Unpad plaintext
    private static func unpad(_ paddedData: Data) throws -> Data {
        // Find the last non-zero byte
        var unpaddedLen = paddedData.count
        while unpaddedLen > 0 && paddedData[unpaddedLen - 1] == 0 {
            unpaddedLen -= 1
        }
        
        guard unpaddedLen >= minPlaintextSize else {
            throw NIP44Error.invalidPadding
        }
        
        return paddedData[0..<unpaddedLen]
    }
}

