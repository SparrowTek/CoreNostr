import Foundation
import Crypto
import CryptoKit

// MARK: - NIP-06 Implementation

/// NIP-06: Basic key derivation from mnemonic seed phrase

public struct NIP06: Sendable {
    /// BIP-44 "purpose" field value per BIP-44 spec.
    private static let bip44Purpose: UInt32 = 44

    /// SLIP-0044 registered coin type for Nostr.
    /// Ref: <https://github.com/satoshilabs/slips/blob/master/slip-0044.md>
    private static let nostrCoinType: UInt32 = 1237

    /// Derives a Nostr key pair from mnemonic using the standard path m/44'/1237'/account'/0/0
    /// - Parameters:
    ///   - mnemonic: BIP39 mnemonic phrase
    ///   - passphrase: Optional passphrase (default: empty)
    ///   - account: Account index (default: 0)
    /// - Returns: KeyPair for Nostr
    /// - Throws: NostrError if derivation fails
    public static func deriveKeyPair(from mnemonic: String, passphrase: String = "", account: UInt32 = 0) throws -> KeyPair {
        // Convert mnemonic to seed
        let seed = try BIP39.mnemonicToSeed(mnemonic, passphrase: passphrase)

        // Create master key
        let masterKey = try BIP32.createMasterKey(from: seed)

        // Derive path m/44'/1237'/account'/0'/0' — BIP-44 purpose, Nostr coin type,
        // all hardened as required by NIP-06.
        let purpose = try BIP32.deriveChild(masterKey, index: BIP32.hardened(bip44Purpose))
        let coinType = try BIP32.deriveChild(purpose, index: BIP32.hardened(nostrCoinType))
        let accountKey = try BIP32.deriveChild(coinType, index: BIP32.hardened(account))
        let change = try BIP32.deriveChild(accountKey, index: BIP32.hardened(0))
        let addressKey = try BIP32.deriveChild(change, index: BIP32.hardened(0))

        // Convert to KeyPair
        let privateKeyHex = addressKey.key.hex
        return try KeyPair(privateKey: privateKeyHex)
    }
    
    /// Generates a new mnemonic and derives a key pair
    /// - Parameters:
    ///   - strength: Entropy strength in bits (default: 256)
    ///   - passphrase: Optional passphrase (default: empty)
    ///   - account: Account index (default: 0)
    /// - Returns: Tuple of (mnemonic, keyPair)
    /// - Throws: NostrError if generation fails
    public static func generateKeyPair(strength: Int = 256, passphrase: String = "", account: UInt32 = 0) throws -> (mnemonic: String, keyPair: KeyPair) {
        let mnemonic = try BIP39.generateMnemonic(strength: strength)
        let keyPair = try deriveKeyPair(from: mnemonic, passphrase: passphrase, account: account)
        return (mnemonic, keyPair)
    }

    // MARK: - Async variants
    //
    // `deriveKeyPair` runs PBKDF2-HMAC-SHA512 with 2048 iterations plus five
    // BIP32 derivation steps. On main-thread callers (SwiftUI onboarding,
    // background restore) this blocks for tens to hundreds of milliseconds.
    // The async variants trampoline to a detached, user-initiated task so the
    // calling actor isn't blocked for that window.

    /// Async variant of ``deriveKeyPair(from:passphrase:account:)`` that runs
    /// on a detached, user-initiated priority task. Prefer this from any
    /// MainActor-isolated call site.
    public static func deriveKeyPairAsync(
        from mnemonic: String,
        passphrase: String = "",
        account: UInt32 = 0
    ) async throws -> KeyPair {
        try await Task.detached(priority: .userInitiated) {
            try deriveKeyPair(from: mnemonic, passphrase: passphrase, account: account)
        }.value
    }

    /// Async variant of ``generateKeyPair(strength:passphrase:account:)``.
    public static func generateKeyPairAsync(
        strength: Int = 256,
        passphrase: String = "",
        account: UInt32 = 0
    ) async throws -> (mnemonic: String, keyPair: KeyPair) {
        try await Task.detached(priority: .userInitiated) {
            try generateKeyPair(strength: strength, passphrase: passphrase, account: account)
        }.value
    }
    
    /// Generates cryptographically secure random bytes.
    /// 
    /// - Parameter count: The number of random bytes to generate
    /// - Returns: Random bytes as Data
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if random generation fails
    public static func randomBytes(count: Int) throws -> Data {
        var bytes = Data(count: count)
        let result = bytes.withUnsafeMutableBytes { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        
        guard result == errSecSuccess else {
            throw NostrError.cryptographyError(operation: .keyGeneration, reason: "Failed to generate random bytes")
        }
        
        return bytes
    }
    
    /// Computes SHA-256 hash of the given data.
    /// 
    /// - Parameter data: The data to hash
    /// - Returns: 32-byte hash result
    public static func sha256(_ data: Data) -> Data {
        let digest = CryptoKit.SHA256.hash(data: data)
        return Data(digest)
    }
    
    /// Computes HMAC-SHA256 of the given message with key.
    /// 
    /// - Parameters:
    ///   - key: The secret key
    ///   - message: The message to authenticate
    /// - Returns: 32-byte HMAC result
    /// - Throws: ``NostrError/cryptographyError(operation:reason:)`` if HMAC computation fails
    public static func hmacSHA256(key: Data, message: Data) throws -> Data {
        let mac = HMAC<CryptoKit.SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Data(mac)
    }
    
    /// Encrypts data using AES-256-CBC.
    /// 
    /// - Parameters:
    ///   - plaintext: The data to encrypt
    ///   - key: 32-byte encryption key
    ///   - iv: 16-byte initialization vector
    /// - Returns: Encrypted data
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if encryption fails
    public static func aesEncrypt(plaintext: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == 32 else {
            throw NostrError.encryptionError(operation: .encrypt, reason: "Key must be 32 bytes")
        }
        guard iv.count == 16 else {
            throw NostrError.encryptionError(operation: .encrypt, reason: "IV must be 16 bytes")
        }
        
        do {
            return try AES256CBC.encrypt(data: plaintext, key: key, iv: iv)
        } catch {
            throw NostrError.encryptionError(operation: .encrypt, reason: error.localizedDescription)
        }
    }
    
    /// Decrypts data using AES-256-CBC.
    /// 
    /// - Parameters:
    ///   - ciphertext: The data to decrypt
    ///   - key: 32-byte decryption key
    ///   - iv: 16-byte initialization vector
    /// - Returns: Decrypted data
    /// - Throws: ``NostrError/encryptionError(operation:reason:)`` if decryption fails
    public static func aesDecrypt(ciphertext: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == 32 else {
            throw NostrError.encryptionError(operation: .decrypt, reason: "Key must be 32 bytes")
        }
        guard iv.count == 16 else {
            throw NostrError.encryptionError(operation: .decrypt, reason: "IV must be 16 bytes")
        }
        
        do {
            return try AES256CBC.decrypt(data: ciphertext, key: key, iv: iv)
        } catch {
            throw NostrError.encryptionError(operation: .decrypt, reason: error.localizedDescription)
        }
    }
}
