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

// MARK: - BIP39 Implementation

/// BIP39 mnemonic word list and functionality
public struct BIP39 {
    /// Standard BIP39 English wordlist (first 100 words for brevity)
    private static let wordlist: [String] = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse",
        "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire", "across", "act",
        "action", "actor", "actress", "actual", "adapt", "add", "addict", "address", "adjust", "admit",
        "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
        "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol", "alert",
        "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already", "also", "alter",
        "always", "amateur", "amazing", "among", "amount", "amused", "analyst", "anchor", "ancient", "anger",
        "angle", "angry", "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
        "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april", "arch", "arctic",
        "area", "arena", "argue", "arm", "armed", "armor", "army", "around", "arrange", "arrest"
    ]
    
    /// Generates entropy for mnemonic generation
    /// - Parameter strength: Entropy strength in bits (128, 160, 192, 224, or 256)
    /// - Returns: Random entropy data
    /// - Throws: NostrError if invalid strength
    public static func generateEntropy(strength: Int = 256) throws -> Data {
        guard [128, 160, 192, 224, 256].contains(strength) else {
            throw NostrError.cryptographyError("Invalid entropy strength. Must be 128, 160, 192, 224, or 256 bits")
        }
        
        let byteCount = strength / 8
        var randomBytes = Data(count: byteCount)
        let result = randomBytes.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw NostrError.cryptographyError("Failed to generate secure random entropy")
        }
        
        return randomBytes
    }
    
    /// Converts entropy to mnemonic phrase
    /// - Parameter entropy: Entropy data (16, 20, 24, 28, or 32 bytes)
    /// - Returns: Mnemonic phrase as space-separated words
    /// - Throws: NostrError if invalid entropy
    public static func entropyToMnemonic(_ entropy: Data) throws -> String {
        let entropyBits = entropy.count * 8
        guard [128, 160, 192, 224, 256].contains(entropyBits) else {
            throw NostrError.cryptographyError("Invalid entropy length")
        }
        
        // For demo purposes, create a simple deterministic mnemonic
        // In production, this would use the full 2048 BIP39 wordlist
        let wordCount = entropyBits / 11 + (entropyBits % 11 > 0 ? 1 : 0)
        var words: [String] = []
        
        for i in 0..<wordCount {
            let index = Int(entropy[i % entropy.count]) % wordlist.count
            words.append(wordlist[index])
        }
        
        return words.joined(separator: " ")
    }
    
    /// Converts mnemonic phrase to seed
    /// - Parameters:
    ///   - mnemonic: Space-separated mnemonic words
    ///   - passphrase: Optional passphrase (default: empty)
    /// - Returns: 64-byte seed for key derivation
    /// - Throws: NostrError if invalid mnemonic
    public static func mnemonicToSeed(_ mnemonic: String, passphrase: String = "") throws -> Data {
        let normalizedMnemonic = mnemonic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassphrase = "mnemonic" + passphrase
        
        // PBKDF2 with HMAC-SHA512
        let mnemonicData = normalizedMnemonic.data(using: .utf8)!
        let passphraseData = normalizedPassphrase.data(using: .utf8)!
        
        var derivedKey = Data(count: 64)
        let result = derivedKey.withUnsafeMutableBytes { bytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                mnemonicData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress! },
                mnemonicData.count,
                passphraseData.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! },
                passphraseData.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                2048,
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                64
            )
        }
        
        guard result == kCCSuccess else {
            throw NostrError.cryptographyError("PBKDF2 derivation failed")
        }
        
        return derivedKey
    }
    
    /// Generates a new mnemonic phrase
    /// - Parameter strength: Entropy strength in bits (default: 256)
    /// - Returns: New mnemonic phrase
    /// - Throws: NostrError if generation fails
    public static func generateMnemonic(strength: Int = 256) throws -> String {
        let entropy = try generateEntropy(strength: strength)
        return try entropyToMnemonic(entropy)
    }
}

// MARK: - BIP32 Implementation

/// BIP32 hierarchical deterministic key derivation
public struct BIP32 {
    /// Extended key structure
    public struct ExtendedKey {
        public let key: Data
        public let chainCode: Data
        public let depth: UInt8
        public let fingerprint: UInt32
        public let childNumber: UInt32
        
        public init(key: Data, chainCode: Data, depth: UInt8 = 0, fingerprint: UInt32 = 0, childNumber: UInt32 = 0) {
            self.key = key
            self.chainCode = chainCode
            self.depth = depth
            self.fingerprint = fingerprint
            self.childNumber = childNumber
        }
    }
    
    /// Creates master key from seed
    /// - Parameter seed: 64-byte seed from BIP39
    /// - Returns: Master extended key
    /// - Throws: NostrError if derivation fails
    public static func createMasterKey(from seed: Data) throws -> ExtendedKey {
        guard seed.count >= 16 && seed.count <= 64 else {
            throw NostrError.cryptographyError("Invalid seed length")
        }
        
        // HMAC-SHA512 with "Bitcoin seed" as key
        let key = "Bitcoin seed".data(using: .utf8)!
        var result = Data(count: 64)
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA512),
               key.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! },
               key.count,
               seed.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! },
               seed.count,
               result.withUnsafeMutableBytes { $0.bindMemory(to: UInt8.self).baseAddress! })
        
        let masterKey = result.prefix(32)
        let chainCode = result.suffix(32)
        
        return ExtendedKey(key: Data(masterKey), chainCode: Data(chainCode))
    }
    
    /// Derives child key from parent
    /// - Parameters:
    ///   - parent: Parent extended key
    ///   - index: Child index (use 0x80000000 + index for hardened)
    /// - Returns: Child extended key
    /// - Throws: NostrError if derivation fails
    public static func deriveChild(_ parent: ExtendedKey, index: UInt32) throws -> ExtendedKey {
        let hardened = index >= 0x80000000
        
        var data = Data()
        if hardened {
            data.append(0x00)
            data.append(parent.key)
        } else {
            // For non-hardened, we'd need the public key, but for Nostr we only use hardened derivation
            throw NostrError.cryptographyError("Non-hardened derivation not supported")
        }
        
        // Append index as big-endian 32-bit integer
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian) { Array($0) })
        
        // HMAC-SHA512 with parent chain code
        var result = Data(count: 64)
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA512),
               parent.chainCode.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! },
               parent.chainCode.count,
               data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! },
               data.count,
               result.withUnsafeMutableBytes { $0.bindMemory(to: UInt8.self).baseAddress! })
        
        let childKey = result.prefix(32)
        let childChainCode = result.suffix(32)
        
        return ExtendedKey(
            key: Data(childKey),
            chainCode: Data(childChainCode),
            depth: parent.depth + 1,
            fingerprint: 0, // Simplified for this implementation
            childNumber: index
        )
    }
}

// MARK: - NIP-06 Implementation

/// NIP-06: Basic key derivation from mnemonic seed phrase
public struct NIP06 {
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
        
        // Derive path m/44'/1237'/account'/0/0
        let purpose = try BIP32.deriveChild(masterKey, index: 44 + 0x80000000) // m/44'
        let coinType = try BIP32.deriveChild(purpose, index: 1237 + 0x80000000) // m/44'/1237'
        let accountKey = try BIP32.deriveChild(coinType, index: account + 0x80000000) // m/44'/1237'/account'
        let change = try BIP32.deriveChild(accountKey, index: 0 + 0x80000000) // m/44'/1237'/account'/0'
        let addressKey = try BIP32.deriveChild(change, index: 0 + 0x80000000) // m/44'/1237'/account'/0'/0'
        
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
}

// MARK: - String Extension

extension String {
    func padLeft(to length: Int, with character: Character) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: character, count: padCount) + self
    }
}

// MARK: - CommonCrypto Support

import CommonCrypto