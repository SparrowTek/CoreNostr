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
import P256K
import CryptoSwift

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
        let sharedSecret: Data
        do {
            sharedSecret = try computeSharedSecret(
                privateKey: senderPrivateKey,
                publicKey: recipientPublicKey
            )
        } catch {
            throw error
        }
        
        // Generate random nonce
        let nonce = generateNonce()
        
        // Derive keys
        let encryptionKey: Data
        let hmacKey: Data
        do {
            (encryptionKey, hmacKey) = try deriveKeys(
                sharedSecret: sharedSecret,
                nonce: nonce
            )
        } catch {
            throw error
        }
        
        // Pad plaintext
        let paddedPlaintext = pad(plaintextData)
        
        // Encrypt
        let ciphertext: Data
        do {
            ciphertext = try encryptChaCha20(
                plaintext: paddedPlaintext,
                key: encryptionKey,
                nonce: nonce
            )
        } catch {
            throw error
        }
        
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
        let payloadWithoutHMAC = Data(payloadData[..<hmacStart])  // Convert SubSequence to Data
        let computedHMAC = computeHMAC(payload: payloadWithoutHMAC, key: hmacKey)
        
        guard computedHMAC == receivedHMAC else {
            throw NIP44Error.hmacVerificationFailed
        }
        
        // Decrypt
        let paddedPlaintext = try decryptChaCha20(
            ciphertext: Data(ciphertext),  // Convert SubSequence to Data
            key: encryptionKey,
            nonce: Data(nonce)  // Convert SubSequence to Data
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
        guard let privKeyData = Data(hex: privateKey),
              privKeyData.count == 32 else {
            throw NIP44Error.invalidPrivateKey
        }
        
        guard let pubKeyData = Data(hex: publicKey),
              pubKeyData.count == 32 else {
            throw NIP44Error.invalidPublicKey
        }
        
        // Create P256K KeyAgreement private key from raw bytes
        let p256kPrivateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privKeyData)
        
        // For x-only public keys, we need to recover the full public key
        // Try with even y-coordinate first (0x02 prefix)
        var compressedPubKey = Data()
        compressedPubKey.append(0x02)
        compressedPubKey.append(pubKeyData)
        
        let p256kPublicKey: P256K.KeyAgreement.PublicKey
        do {
            p256kPublicKey = try P256K.KeyAgreement.PublicKey(dataRepresentation: compressedPubKey)
        } catch {
            // If even y-coordinate fails, try odd (0x03 prefix)
            compressedPubKey[0] = 0x03
            p256kPublicKey = try P256K.KeyAgreement.PublicKey(dataRepresentation: compressedPubKey)
        }
        
        // Compute the shared secret (x-coordinate only)
        let sharedSecret = try p256kPrivateKey.sharedSecretFromKeyAgreement(with: p256kPublicKey)
        
        // P256K returns a SharedSecret which might be in compressed format
        // We need the raw x-coordinate for NIP-44
        let sharedSecretData = Data(sharedSecret.bytes)
        
        if sharedSecretData.count == 33 {
            // P256K returned compressed format (0x02/0x03 + 32 bytes)
            // Skip the first byte to get the x-coordinate
            return Data(sharedSecretData[1..<33])
        } else if sharedSecretData.count == 32 {
            // Already just the x-coordinate
            return sharedSecretData
        } else if sharedSecretData.count == 64 {
            // Might be SHA512 hash, take first 32 bytes
            return Data(sharedSecretData[0..<32])
        } else {
            // Unexpected size
            throw NIP44Error.encryptionFailed
        }
    }
    
    /// Generate a random 32-byte nonce
    private static func generateNonce() -> Data {
        var nonce = Data(count: 32)
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        guard result == errSecSuccess else {
            // If random generation fails, use a fallback
            // This should never happen in practice
            return Data(repeating: 0, count: 32)
        }
        return nonce
    }
    
    /// Derive encryption and HMAC keys from shared secret and nonce
    private static func deriveKeys(
        sharedSecret: Data,
        nonce: Data
    ) throws -> (encryptionKey: Data, hmacKey: Data) {
        // Step 1: Derive conversation key using HKDF-extract
        // salt = "nip44-v2", IKM = shared_x (32 bytes)
        let salt = "nip44-v2".data(using: .utf8)!
        
        // HKDF-extract produces a fixed-size output (32 bytes with SHA256)
        let conversationKey = HKDF<CryptoKit.SHA256>.extract(
            inputKeyMaterial: SymmetricKey(data: sharedSecret),
            salt: salt
        )
        
        // Step 2: Derive per-message keys using HKDF-expand
        // PRK = conversation_key, info = nonce (32 bytes), L = 76 bytes
        let expandedKey = HKDF<CryptoKit.SHA256>.expand(
            pseudoRandomKey: conversationKey,
            info: nonce,
            outputByteCount: 76
        )
        
        // Convert SymmetricKey to Data
        let keyData = expandedKey.withUnsafeBytes { Data($0) }
        
        // Slice the output according to spec:
        // chacha_key: bytes 0..32
        // chacha_nonce: bytes 32..44 (not used in our case)
        // hmac_key: bytes 44..76
        let encryptionKey = Data(keyData[0..<32])
        let hmacKey = Data(keyData[44..<76])
        
        return (encryptionKey, hmacKey)
    }
    
    /// Encrypt using ChaCha20
    private static func encryptChaCha20(
        plaintext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        // ChaCha20 uses a 12-byte nonce, we use first 12 bytes of our 32-byte nonce
        let chachaNonceData = Array(nonce[0..<12])
        let keyArray = Array(key)
        let plaintextArray = Array(plaintext)
        
        do {
            let chacha = try CryptoSwift.ChaCha20(key: keyArray, iv: chachaNonceData)
            let encrypted = try chacha.encrypt(plaintextArray)
            return Data(encrypted)
        } catch {
            throw NIP44Error.encryptionFailed
        }
    }
    
    /// Decrypt using ChaCha20
    private static func decryptChaCha20(
        ciphertext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        // ChaCha20 uses a 12-byte nonce
        let chachaNonceData = Array(nonce[0..<12])
        let keyArray = Array(key)
        let ciphertextArray = Array(ciphertext)
        
        do {
            let chacha = try CryptoSwift.ChaCha20(key: keyArray, iv: chachaNonceData)
            let decrypted = try chacha.decrypt(ciphertextArray)
            return Data(decrypted)
        } catch {
            throw NIP44Error.decryptionFailed
        }
    }
    
    /// Compute HMAC-SHA256
    private static func computeHMAC(payload: Data, key: Data) -> Data {
        let mac = HMAC<CryptoKit.SHA256>.authenticationCode(
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

