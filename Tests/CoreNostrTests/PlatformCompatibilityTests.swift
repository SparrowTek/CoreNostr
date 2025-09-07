import Testing
import Foundation
import P256K
@testable import CoreNostr

@Suite("Platform Compatibility: P256K and Cross-Platform Support")
struct PlatformCompatibilityTests {
    
    // MARK: - P256K Basic Operations
    
    @Test("P256K Schnorr key generation")
    func testP256KSchnorrKeyGeneration() throws {
        // Test that P256K can generate keys
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.xonly
        
        #expect(privateKey.dataRepresentation.count == 32)
        #expect(publicKey.bytes.count == 32)
    }
    
    @Test("P256K Schnorr signing and verification")
    func testP256KSchnorrSigningVerification() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.xonly
        
        let message = "Test message for P256K".data(using: .utf8)!
        
        // Sign
        let signature = try privateKey.signature(for: message)
        
        // Verify
        let isValid = publicKey.isValidSignature(signature, for: message)
        #expect(isValid == true)
        
        // Verify with wrong message should fail
        let wrongMessage = "Wrong message".data(using: .utf8)!
        let isInvalid = publicKey.isValidSignature(signature, for: wrongMessage)
        #expect(isInvalid == false)
    }
    
    @Test("P256K KeyAgreement ECDH")
    func testP256KKeyAgreementECDH() throws {
        // Generate two key pairs
        let alicePrivate = try P256K.KeyAgreement.PrivateKey()
        let alicePublic = alicePrivate.publicKey
        
        let bobPrivate = try P256K.KeyAgreement.PrivateKey()
        let bobPublic = bobPrivate.publicKey
        
        // Compute shared secrets
        let aliceShared = try alicePrivate.sharedSecretFromKeyAgreement(with: bobPublic)
        let bobShared = try bobPrivate.sharedSecretFromKeyAgreement(with: alicePublic)
        
        // Shared secrets should be equal
        #expect(Data(aliceShared.bytes) == Data(bobShared.bytes))
    }
    
    // MARK: - CoreNostr Integration with P256K
    
    @Test("CoreNostr KeyPair uses P256K correctly")
    func testCoreNostrKeyPairP256K() throws {
        // Generate a key pair using CoreNostr
        let keyPair = try KeyPair.generate()
        
        // Verify the keys are valid P256K keys
        let privateKeyData = Data(hex: keyPair.privateKey)!
        let publicKeyData = Data(hex: keyPair.publicKey)!
        
        #expect(privateKeyData.count == 32)
        #expect(publicKeyData.count == 32)
        
        // Verify we can recreate P256K keys from the data
        let p256kPrivate = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyData)
        let p256kPublicBytes = p256kPrivate.xonly.bytes
        
        #expect(Data(p256kPublicBytes) == publicKeyData)
    }
    
    @Test("Event signing compatibility with P256K")
    func testEventSigningP256KCompatibility() throws {
        let keyPair = try KeyPair.generate()
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: 1,
            tags: [],
            content: "Test event for P256K compatibility"
        )
        
        // Sign the event
        let signedEvent = try keyPair.signEvent(event)
        
        // Verify using P256K directly
        let serialized = signedEvent.serializedForSigning()
        let eventData = Data(serialized.utf8)
        
        let publicKeyData = Data(hex: signedEvent.pubkey)!
        let signatureData = Data(hex: signedEvent.sig)!
        
        let p256kPublicKey = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyData)
        let p256kSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureData)
        
        let isValid = p256kPublicKey.isValidSignature(p256kSignature, for: eventData)
        #expect(isValid == true)
    }
    
    // MARK: - Platform-Specific Features
    
    @Test("SecRandomCopyBytes availability")
    func testSecRandomCopyBytesAvailability() {
        // Test that SecRandomCopyBytes works on all platforms
        var randomBytes = Data(count: 32)
        let result = randomBytes.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        
        #expect(result == errSecSuccess)
        #expect(randomBytes.count == 32)
        // Verify it's actually random (not all zeros)
        #expect(!randomBytes.allSatisfy { $0 == 0 })
    }
    
    @Test("CryptoKit availability on all platforms")
    func testCryptoKitAvailability() throws {
        // Test basic CryptoKit operations
        let data = "Test data".data(using: .utf8)!
        
        // SHA256
        let hash = CryptoKit.SHA256.hash(data: data)
        #expect(hash.description.count > 0)
        
        // HMAC
        let key = SymmetricKey(size: .bits256)
        let hmac = HMAC<CryptoKit.SHA256>.authenticationCode(for: data, using: key)
        #expect(Data(hmac).count == 32)
        
        // HKDF
        let salt = "salt".data(using: .utf8)!
        let info = "info".data(using: .utf8)!
        let prk = HKDF<CryptoKit.SHA256>.extract(
            inputKeyMaterial: SymmetricKey(data: data),
            salt: salt
        )
        let okm = HKDF<CryptoKit.SHA256>.expand(
            pseudoRandomKey: prk,
            info: info,
            outputByteCount: 32
        )
        #expect(okm.withUnsafeBytes { Data($0) }.count == 32)
    }
    
    // MARK: - Cross-Platform Data Encoding
    
    @Test("Hex encoding consistency across platforms")
    func testHexEncodingConsistency() {
        let testData = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF])
        let hexString = testData.hex
        
        #expect(hexString == "0123456789abcdef")
        
        // Test that hex encoding is consistent
        let testData2 = Data([0xFF, 0x00, 0xAA, 0x55])
        let hexString2 = testData2.hex
        #expect(hexString2 == "ff00aa55")
        
        // Test empty data
        let emptyData = Data()
        #expect(emptyData.hex == "")
    }
    
    @Test("Base64 encoding consistency")
    func testBase64EncodingConsistency() {
        let testData = Data("Test data for base64 encoding".utf8)
        let base64 = testData.base64EncodedString()
        
        // Decode and verify round-trip
        let decoded = Data(base64Encoded: base64)
        #expect(decoded == testData)
    }
    
    // MARK: - Memory and Performance
    
    @Test("Key generation performance baseline")
    func testKeyGenerationPerformance() throws {
        let startTime = Date()
        
        // Generate 100 key pairs
        for _ in 0..<100 {
            _ = try KeyPair.generate()
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete in reasonable time (< 5 seconds for 100 keys)
        #expect(elapsed < 5.0)
        
        // Average time per key
        let avgTime = elapsed / 100.0
        print("Average key generation time: \(avgTime * 1000)ms")
    }
    
    @Test("Event signing performance baseline")
    func testEventSigningPerformance() throws {
        let keyPair = try KeyPair.generate()
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: 1,
            tags: [],
            content: "Performance test event"
        )
        
        let startTime = Date()
        
        // Sign 1000 events
        for _ in 0..<1000 {
            _ = try keyPair.signEvent(event)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete in reasonable time (< 5 seconds for 1000 signatures)
        #expect(elapsed < 5.0)
        
        // Average time per signature
        let avgTime = elapsed / 1000.0
        print("Average signing time: \(avgTime * 1000)ms")
    }
    
    // MARK: - Compile-time Platform Checks
    
    @Test("Platform conditional compilation")
    func testPlatformConditionalCompilation() {
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #elseif os(tvOS)
        let platform = "tvOS"
        #elseif os(watchOS)
        let platform = "watchOS"
        #else
        let platform = "Unknown"
        #endif
        
        print("Running on platform: \(platform)")
        #expect(platform != "Unknown")
    }
    
    @Test("Architecture detection")
    func testArchitectureDetection() {
        #if arch(x86_64)
        let arch = "x86_64"
        #elseif arch(arm64)
        let arch = "arm64"
        #elseif arch(arm)
        let arch = "arm"
        #else
        let arch = "unknown"
        #endif
        
        print("Running on architecture: \(arch)")
        #expect(arch != "unknown")
    }
    
    // MARK: - Version Compatibility
    
    @Test("P256K version compatibility")
    func testP256KVersionCompatibility() throws {
        // Test that we're using compatible P256K features
        // This will fail to compile if P256K API changes incompatibly
        
        // Test Schnorr namespace exists
        _ = try P256K.Schnorr.PrivateKey()
        
        // Test KeyAgreement namespace exists
        _ = try P256K.KeyAgreement.PrivateKey()
        
        // Test XonlyKey type exists
        let privateKey = try P256K.Schnorr.PrivateKey()
        _ = privateKey.xonly
        
        // If this compiles and runs, we have version compatibility
        #expect(Bool(true))
    }
}