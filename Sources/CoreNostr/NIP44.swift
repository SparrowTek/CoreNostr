//
//  NIP44.swift
//  CoreNostr
//
//  NIP-44: Encrypted Payloads
//  https://github.com/nostr-protocol/nips/blob/master/44.md
//
//

import Foundation
import CryptoKit
import P256K

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
        recipientPublicKey: String,
        nonce overrideNonce: Data? = nil
    ) throws -> String {
        // Validate keys
        try Validation.validatePrivateKey(senderPrivateKey)
        try Validation.validatePublicKey(recipientPublicKey)
        
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
        
        // Generate nonce (allow deterministic override for testing)
        if let overrideNonce, overrideNonce.count != 32 {
            throw NIP44Error.invalidPayload
        }
        let nonce = try overrideNonce ?? generateNonce()
        
        // Derive keys (ChaCha key, ChaCha nonce, HMAC key)
        let chachaKey: Data
        let chachaNonce: Data
        let hmacKey: Data
        do {
            (chachaKey, chachaNonce, hmacKey) = try deriveKeys(
                sharedSecret: sharedSecret,
                nonce: nonce
            )
        } catch {
            throw error
        }
        
        // Pad plaintext
        let paddedPlaintext = pad(plaintextData)
        
        // Encrypt using derived ChaCha key and nonce
        let ciphertext: Data
        do {
            ciphertext = try encryptChaCha20(
                plaintext: paddedPlaintext,
                key: chachaKey,
                nonce: chachaNonce
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
        // Validate keys
        try Validation.validatePrivateKey(recipientPrivateKey)
        try Validation.validatePublicKey(senderPublicKey)
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
        // Derive keys (ChaCha key, ChaCha nonce, HMAC key)
        let (chachaKey, chachaNonce, hmacKey) = try deriveKeys(
            sharedSecret: sharedSecret,
            nonce: Data(nonce)
        )
        // Verify HMAC
        let payloadWithoutHMAC = Data(payloadData[..<hmacStart])  // Convert SubSequence to Data
        let computedHMAC = computeHMAC(payload: payloadWithoutHMAC, key: hmacKey)
        
        // Use constant-time comparison to prevent timing side-channels
        guard Data(computedHMAC).constantTimeEquals(Data(receivedHMAC)) else {
            throw NIP44Error.hmacVerificationFailed
        }
        
        // Decrypt using derived ChaCha key and nonce
        let paddedPlaintext = try decryptChaCha20(
            ciphertext: Data(ciphertext),  // Convert SubSequence to Data
            key: chachaKey,
            nonce: chachaNonce
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
    
    /// Generate a random 32-byte nonce using the system CSPRNG.
    ///
    /// - Throws: `NIP44Error.encryptionFailed` if secure random generation fails.
    ///
    /// - Important: This function throws on failure rather than falling back to
    ///   predictable values. Using a zero or predictable nonce would be catastrophic
    ///   for encryption security.
    private static func generateNonce() throws -> Data {
        var nonce = Data(count: 32)
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        guard result == errSecSuccess else {
            // Never fall back to predictable nonces - this would be a security catastrophe
            throw NIP44Error.encryptionFailed
        }
        return nonce
    }
    
    /// Derive message keys from shared secret and nonce.
    ///
    /// Per NIP-44 spec:
    /// 1. Derive conversation key: `HKDF-extract(IKM=shared_x, salt="nip44-v2")`
    /// 2. Derive message keys: `HKDF-expand(PRK=conversation_key, info=nonce, L=76)`
    /// 3. Split: `chacha_key[0:32], chacha_nonce[32:44], hmac_key[44:76]`
    private static func deriveKeys(
        sharedSecret: Data,
        nonce: Data
    ) throws -> (chachaKey: Data, chachaNonce: Data, hmacKey: Data) {
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
        // chacha_nonce: bytes 32..44
        // hmac_key: bytes 44..76
        let chachaKey = Data(keyData[0..<32])
        let chachaNonce = Data(keyData[32..<44])
        let hmacKey = Data(keyData[44..<76])
        
        return (chachaKey, chachaNonce, hmacKey)
    }
    
    /// Encrypt using ChaCha20.
    ///
    /// - Parameters:
    ///   - plaintext: The padded plaintext to encrypt
    ///   - key: 32-byte ChaCha20 key (derived from HKDF)
    ///   - nonce: 12-byte ChaCha20 nonce (derived from HKDF, bytes 32..44)
    private static func encryptChaCha20(
        plaintext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        guard nonce.count == 12 else {
            throw NIP44Error.encryptionFailed
        }
        
        do {
            let chacha = try ChaCha20(key: key, nonce: nonce)
            return chacha.process(plaintext)
        } catch {
            throw NIP44Error.encryptionFailed
        }
    }
    
    /// Decrypt using ChaCha20.
    ///
    /// - Parameters:
    ///   - ciphertext: The ciphertext to decrypt
    ///   - key: 32-byte ChaCha20 key (derived from HKDF)
    ///   - nonce: 12-byte ChaCha20 nonce (derived from HKDF, bytes 32..44)
    private static func decryptChaCha20(
        ciphertext: Data,
        key: Data,
        nonce: Data
    ) throws -> Data {
        guard nonce.count == 12 else {
            throw NIP44Error.decryptionFailed
        }
        
        do {
            let chacha = try ChaCha20(key: key, nonce: nonce)
            return chacha.process(ciphertext)
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
    
    /// Calculate the padded length for a given unpadded length per NIP-44 spec.
    ///
    /// The algorithm ensures padding grows in powers of two, with a minimum of 32 bytes.
    /// This provides consistent padding that partially obscures message length.
    ///
    /// From NIP-44 spec:
    /// ```
    /// def calc_padded_len(unpadded_len):
    ///   next_power = 1 << (floor(log2(unpadded_len - 1))) + 1
    ///   if next_power <= 256:
    ///     chunk = 32
    ///   else:
    ///     chunk = next_power / 8
    ///   if unpadded_len <= 32:
    ///     return 32
    ///   else:
    ///     return chunk * (floor((unpadded_len - 1) / chunk) + 1)
    /// ```
    private static func calcPaddedLen(_ unpaddedLen: Int) -> Int {
        // Messages up to 32 bytes always pad to 32
        if unpaddedLen <= 32 {
            return 32
        }
        
        // Calculate next power of 2 greater than (unpaddedLen - 1)
        // floor(log2(unpaddedLen - 1)) + 1 gives us the exponent for next power
        let nextPower = 1 << (Int(floor(log2(Double(unpaddedLen - 1)))) + 1)
        
        // Chunk size is 32 for small messages, otherwise nextPower / 8
        let chunk: Int
        if nextPower <= 256 {
            chunk = 32
        } else {
            chunk = nextPower / 8
        }
        
        // Round up to next chunk boundary
        return chunk * (((unpaddedLen - 1) / chunk) + 1)
    }
    
    /// Pad plaintext according to NIP-44 specification.
    ///
    /// Padding format: `[plaintext_length: u16 BE][plaintext][zero_bytes]`
    ///
    /// The 2-byte big-endian length prefix allows precise extraction during unpadding,
    /// even if the plaintext contains trailing zero bytes.
    private static func pad(_ plaintext: Data) -> Data {
        let unpaddedLen = plaintext.count
        let paddedLen = calcPaddedLen(unpaddedLen)
        
        // Build padded message: [2-byte BE length][plaintext][zeros]
        var result = Data(capacity: 2 + paddedLen)
        
        // Write plaintext length as 2-byte big-endian
        result.append(UInt8((unpaddedLen >> 8) & 0xFF))
        result.append(UInt8(unpaddedLen & 0xFF))
        
        // Append plaintext
        result.append(plaintext)
        
        // Append zero padding to reach paddedLen total (after the 2-byte prefix)
        let zeroCount = paddedLen - unpaddedLen
        if zeroCount > 0 {
            result.append(Data(repeating: 0, count: zeroCount))
        }
        
        return result
    }
    
    /// Unpad plaintext according to NIP-44 specification.
    ///
    /// Reads the 2-byte big-endian length prefix and extracts exactly that many bytes.
    /// Validates that the padding is correct per the spec.
    private static func unpad(_ paddedData: Data) throws -> Data {
        // Need at least 2 bytes for length prefix + 1 byte minimum plaintext
        guard paddedData.count >= 3 else {
            throw NIP44Error.invalidPadding
        }
        
        // Read 2-byte big-endian length prefix
        let unpaddedLen = (Int(paddedData[0]) << 8) | Int(paddedData[1])
        
        // Validate length is within allowed range
        guard unpaddedLen >= minPlaintextSize && unpaddedLen <= maxPlaintextSize else {
            throw NIP44Error.invalidPadding
        }
        
        // Validate we have enough data
        guard paddedData.count >= 2 + unpaddedLen else {
            throw NIP44Error.invalidPadding
        }
        
        // Extract plaintext (bytes after 2-byte prefix)
        let plaintext = Data(paddedData[2..<(2 + unpaddedLen)])
        
        // Verify padding length matches expected calculation
        let expectedPaddedLen = calcPaddedLen(unpaddedLen)
        guard paddedData.count == 2 + expectedPaddedLen else {
            throw NIP44Error.invalidPadding
        }
        
        // Verify all padding bytes are zero (constant-time would be better but this is post-MAC)
        for i in (2 + unpaddedLen)..<paddedData.count {
            guard paddedData[i] == 0 else {
                throw NIP44Error.invalidPadding
            }
        }
        
        return plaintext
    }

    // MARK: - Test Helpers
    
    /// Internal helper for tests: derive shared secret for deterministic vector verification
    internal static func testSharedSecret(
        privateKey: String,
        publicKey: String
    ) throws -> Data {
        try computeSharedSecret(privateKey: privateKey, publicKey: publicKey)
    }
    
    /// Internal helper for tests: derive message keys from shared secret and nonce
    /// Returns: (chachaKey, chachaNonce, hmacKey)
    internal static func testDerivedKeys(
        sharedSecret: Data,
        nonce: Data
    ) throws -> (chachaKey: Data, chachaNonce: Data, hmacKey: Data) {
        try deriveKeys(sharedSecret: sharedSecret, nonce: nonce)
    }
    
    /// Internal helper for tests: compute HMAC over payload
    internal static func testComputeHMAC(payload: Data, key: Data) -> Data {
        computeHMAC(payload: payload, key: key)
    }
}
