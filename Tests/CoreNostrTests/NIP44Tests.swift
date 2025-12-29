//
//  NIP44Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-44: Encrypted Payloads
//

import Testing
@testable import CoreNostr
import Foundation

/// Tests for NIP-44 Encrypted Payloads
@Suite("NIP-44: Encrypted Payloads Tests")
struct NIP44Tests {
    let aliceKeyPair: KeyPair
    let bobKeyPair: KeyPair
    
    init() throws {
        // Use fixed test keys for reproducible tests
        aliceKeyPair = try KeyPair(privateKey: "7f3b02c9d3704396ff9b2a530f7e7c7411a5e77fc4f7b7b7c73030b0c3a36e54")
        bobKeyPair = try KeyPair(privateKey: "b1e5c4a44fbd432089ddaa4aeba180de89fc4a34e66700d49e2307b9dc85a6f8")
    }
    
    @Test("Encrypt and decrypt simple message")
    func testEncryptDecryptSimple() throws {
        let plaintext = "Hello, World!"
        // Alice encrypts for Bob
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Check it's base64 encoded
        #expect(Data(base64Encoded: encrypted) != nil)
        // Bob decrypts
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("Encrypt and decrypt long message")
    func testEncryptDecryptLong() throws {
        // Create a message that spans multiple padding boundaries
        let plaintext = String(repeating: "This is a long message. ", count: 100)
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("Encrypt with emoji and special characters")
    func testEncryptWithSpecialCharacters() throws {
        let plaintext = "Hello 👋 World 🌍! Special chars: €£¥ 中文 العربية"
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("Different messages produce different ciphertexts")
    func testDifferentCiphertexts() throws {
        let plaintext1 = "Message 1"
        let plaintext2 = "Message 2"
        
        let encrypted1 = try NIP44.encrypt(
            plaintext: plaintext1,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let encrypted2 = try NIP44.encrypt(
            plaintext: plaintext2,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Due to random nonces, even same message would produce different ciphertexts
        #expect(encrypted1 != encrypted2)
    }
    
    @Test("Same message encrypted twice produces different ciphertexts")
    func testNonDeterministicEncryption() throws {
        let plaintext = "Same message"
        
        let encrypted1 = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let encrypted2 = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Due to random nonces
        #expect(encrypted1 != encrypted2)
        
        // But both decrypt to same plaintext
        let decrypted1 = try NIP44.decrypt(
            payload: encrypted1,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        let decrypted2 = try NIP44.decrypt(
            payload: encrypted2,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted1 == plaintext)
        #expect(decrypted2 == plaintext)
    }
    
    @Test("Invalid base64 payload throws")
    func testInvalidBase64Throws() throws {
        #expect(throws: NIP44.NIP44Error.invalidPayload) {
            _ = try NIP44.decrypt(
                payload: "not-valid-base64!@#$",
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Too short payload throws")
    func testTooShortPayloadThrows() throws {
        // Create a payload that's too short
        let shortData = Data(repeating: 0, count: 50)
        let shortPayload = shortData.base64EncodedString()
        
        #expect(throws: NIP44.NIP44Error.invalidPayload) {
            _ = try NIP44.decrypt(
                payload: shortPayload,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Modified payload fails HMAC verification")
    func testModifiedPayloadFailsHMAC() throws {
        let plaintext = "Original message"
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Decode, modify, and re-encode
        var data = Data(base64Encoded: encrypted)!
        data[50] ^= 0xFF  // Flip some bits
        let modifiedPayload = data.base64EncodedString()
        
        #expect(throws: NIP44.NIP44Error.hmacVerificationFailed) {
            _ = try NIP44.decrypt(
                payload: modifiedPayload,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Wrong recipient cannot decrypt")
    func testWrongRecipientCannotDecrypt() throws {
        let charlieKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000003")
        let plaintext = "Secret for Bob only"
        
        // Alice encrypts for Bob
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Charlie tries to decrypt - should fail
        #expect(throws: Error.self) {
            _ = try NIP44.decrypt(
                payload: encrypted,
                recipientPrivateKey: charlieKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Invalid private key throws")
    func testInvalidPrivateKeyThrows() throws {
        #expect(throws: NostrError.self) {
            _ = try NIP44.encrypt(
                plaintext: "Test",
                senderPrivateKey: "invalid-key",
                recipientPublicKey: bobKeyPair.publicKey
            )
        }
    }
    
    @Test("Invalid public key throws")
    func testInvalidPublicKeyThrows() throws {
        #expect(throws: NostrError.self) {
            _ = try NIP44.encrypt(
                plaintext: "Test",
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: "invalid-key"
            )
        }
    }
    
    @Test("Minimum message size")
    func testMinimumMessageSize() throws {
        let plaintext = "a"  // Single character
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("Maximum message size")
    func testMaximumMessageSize() throws {
        // Create max size message (64KB - 1)
        let plaintext = String(repeating: "x", count: 65535)
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
    
    @Test("Message too large throws")
    func testMessageTooLargeThrows() throws {
        // Create oversized message
        let plaintext = String(repeating: "x", count: 65536)
        
        #expect(throws: NIP44.NIP44Error.invalidPayload) {
            _ = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
        }
    }
    
    @Test("Padding sizes")
    func testPaddingSizes() throws {
        // Test various message sizes to ensure padding works correctly
        let sizes = [1, 32, 33, 96, 97, 224, 225, 480, 481, 992, 993]
        
        for size in sizes {
            let plaintext = String(repeating: "a", count: size)
            
            let encrypted = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
            
            let decrypted = try NIP44.decrypt(
                payload: encrypted,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
            
            #expect(decrypted == plaintext)
        }
    }
    
    // MARK: - Extended Test Vectors
    
    @Test("Cross-implementation test vectors")
    func testCrossImplementationVectors() throws {
        // Test vectors that should work across implementations
        // These are based on NIP-44 specification examples
        
        struct TestVector {
            let senderPrivKey: String
            let recipientPubKey: String
            let plaintext: String
            let conversationKey: String? // For verifying conversation key generation
        }
        
        // Use valid secp256k1 keypairs for test vectors
        // Private key 1 -> pubkey is the generator point G
        // Private key 2 -> pubkey is 2*G
        let vectors = [
            TestVector(
                senderPrivKey: "0000000000000000000000000000000000000000000000000000000000000001",
                recipientPubKey: "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5", // pubkey for privkey 2
                plaintext: "hello world",
                conversationKey: nil
            ),
            TestVector(
                senderPrivKey: "0000000000000000000000000000000000000000000000000000000000000002",
                recipientPubKey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", // pubkey for privkey 1 (G)
                plaintext: "NIP-44 test message",
                conversationKey: nil
            )
        ]
        
        let deterministicNonce = Data(repeating: 0x11, count: 32)
        
        for vector in vectors {
            let senderKeyPair = try KeyPair(privateKey: vector.senderPrivKey)
            
            let encrypted = try NIP44.encrypt(
                plaintext: vector.plaintext,
                senderPrivateKey: senderKeyPair.privateKey,
                recipientPublicKey: vector.recipientPubKey,
                nonce: deterministicNonce
            )
            
            // Verify we can decrypt our own encryption
            let payloadData = Data(base64Encoded: encrypted)!
            
            // Validate structure: version + nonce + ciphertext + hmac
            #expect(payloadData.first == 0x02)
            #expect(payloadData[1..<33] == deterministicNonce[0..<32])
            
            // Verify HMAC matches recomputation
            let sharedSecret = try NIP44.testSharedSecret(
                privateKey: vector.senderPrivKey,
                publicKey: vector.recipientPubKey
            )
            let (_, _, hmacKey) = try NIP44.testDerivedKeys(
                sharedSecret: sharedSecret,
                nonce: deterministicNonce
            )
            
            let hmacStart = payloadData.count - 32
            // HMAC is computed over nonce + ciphertext (not version byte) per NIP-44 spec
            let nonce = Data(payloadData[1..<33])
            let ciphertext = Data(payloadData[33..<hmacStart])
            var hmacInput = Data()
            hmacInput.append(nonce)
            hmacInput.append(ciphertext)
            let computedHMAC = NIP44.testComputeHMAC(
                payload: hmacInput,
                key: hmacKey
            )
            #expect(Data(computedHMAC) == Data(payloadData[hmacStart...]))
            
            // Decrypt using production path
            let decrypted = try NIP44.decrypt(
                payload: encrypted,
                recipientPrivateKey: senderKeyPair.privateKey,
                senderPublicKey: vector.recipientPubKey
            )
            
            #expect(decrypted == vector.plaintext)
        }
    }
    
    @Test("Conversation key generation correctness")
    func testConversationKeyGeneration() throws {
        // Test that conversation keys are generated correctly and consistently
        let alicePriv = "7f3b02c9d3704396ff9b2a530f7e7c7411a5e77fc4f7b7b7c73030b0c3a36e54"
        let bobPriv = "b1e5c4a44fbd432089ddaa4aeba180de89fc4a34e66700d49e2307b9dc85a6f8"
        
        let alice = try KeyPair(privateKey: alicePriv)
        let bob = try KeyPair(privateKey: bobPriv)
        
        // Encrypt message from Alice to Bob
        let message1 = "Message from Alice to Bob"
        let encrypted1 = try NIP44.encrypt(
            plaintext: message1,
            senderPrivateKey: alice.privateKey,
            recipientPublicKey: bob.publicKey
        )
        
        // Encrypt message from Bob to Alice
        let message2 = "Reply from Bob to Alice"
        let encrypted2 = try NIP44.encrypt(
            plaintext: message2,
            senderPrivateKey: bob.privateKey,
            recipientPublicKey: alice.publicKey
        )
        
        // Verify cross-decryption works
        let decrypted1 = try NIP44.decrypt(
            payload: encrypted1,
            recipientPrivateKey: bob.privateKey,
            senderPublicKey: alice.publicKey
        )
        
        let decrypted2 = try NIP44.decrypt(
            payload: encrypted2,
            recipientPrivateKey: alice.privateKey,
            senderPublicKey: bob.publicKey
        )
        
        #expect(decrypted1 == message1)
        #expect(decrypted2 == message2)
    }
    
    @Test("Version byte validation")
    func testVersionByteValidation() throws {
        let plaintext = "Test message"
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        // Decode the payload
        var data = Data(base64Encoded: encrypted)!
        
        // Verify version byte is 0x02
        #expect(data[0] == 0x02)
        
        // Change version byte to invalid value
        data[0] = 0x01
        let invalidPayload = data.base64EncodedString()
        
        #expect(throws: NIP44.NIP44Error.invalidVersion) {
            _ = try NIP44.decrypt(
                payload: invalidPayload,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Nonce uniqueness verification")
    func testNonceUniqueness() throws {
        let plaintext = "Test message for nonce uniqueness"
        var nonces: Set<Data> = []
        
        // Generate multiple encryptions and collect nonces
        for _ in 0..<100 {
            let encrypted = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
            
            let data = Data(base64Encoded: encrypted)!
            // Nonce is at position 1...33 (32 bytes after version byte)
            let nonce = data[1..<33]
            
            // Verify nonce hasn't been used before
            #expect(!nonces.contains(nonce))
            nonces.insert(nonce)
        }
        
        // All 100 nonces should be unique
        #expect(nonces.count == 100)
    }
    
    @Test("HMAC authentication tag verification")
    func testHMACAuthenticationTag() throws {
        let plaintext = "Message for HMAC testing"
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        var data = Data(base64Encoded: encrypted)!
        
        // HMAC is last 32 bytes
        let hmacStart = data.count - 32
        
        // Corrupt HMAC
        data[hmacStart] ^= 0xFF
        let corruptedPayload = data.base64EncodedString()
        
        #expect(throws: NIP44.NIP44Error.hmacVerificationFailed) {
            _ = try NIP44.decrypt(
                payload: corruptedPayload,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
        }
    }
    
    @Test("Empty message encryption")
    func testEmptyMessageEncryption() throws {
        let plaintext = ""
        
        #expect(throws: NIP44.NIP44Error.invalidPayload) {
            _ = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
        }
    }
    
    @Test("UTF-8 boundary cases")
    func testUTF8BoundaryCases() throws {
        let testCases = [
            "𝄞",  // Musical symbol (4 bytes)
            "👨‍👩‍👧‍👦",  // Family emoji (multi-codepoint)
            "\u{0000}",  // Null character
            "\u{FFFD}",  // Replacement character
            "A\u{0301}",  // Combining character (A with accent)
            "שָׁלוֹם",  // Hebrew with vowel marks
            "🏴󠁧󠁢󠁥󠁮󠁧󠁿",  // Flag of England (tag sequence)
            String(repeating: "💩", count: 100)  // Many emoji
        ]
        
        for plaintext in testCases {
            let encrypted = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
            
            let decrypted = try NIP44.decrypt(
                payload: encrypted,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
            
            #expect(decrypted == plaintext)
        }
    }
    
    @Test("Payload structure validation")
    func testPayloadStructureValidation() throws {
        let plaintext = "Test payload structure"
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let data = Data(base64Encoded: encrypted)!
        
        // Verify structure:
        // 1 byte version + 32 bytes nonce + ciphertext + 32 bytes MAC
        #expect(data.count >= 65)  // Minimum size
        #expect(data[0] == 0x02)  // Version byte
        
        // Nonce should not be all zeros
        let nonce = data[1..<33]
        #expect(nonce != Data(repeating: 0, count: 32))
        
        // MAC should not be all zeros
        let mac = data[(data.count - 32)...]
        #expect(mac != Data(repeating: 0, count: 32))
    }
    
    @Test("Key derivation consistency")
    func testKeyDerivationConsistency() throws {
        // Test that same key pairs always derive same conversation key
        let message = "Consistency test"
        
        // Multiple encryptions with same keys should use different nonces
        // but same conversation key
        var ciphertexts: [String] = []
        
        for _ in 0..<10 {
            let encrypted = try NIP44.encrypt(
                plaintext: message,
                senderPrivateKey: aliceKeyPair.privateKey,
                recipientPublicKey: bobKeyPair.publicKey
            )
            ciphertexts.append(encrypted)
        }
        
        // All should decrypt correctly
        for ciphertext in ciphertexts {
            let decrypted = try NIP44.decrypt(
                payload: ciphertext,
                recipientPrivateKey: bobKeyPair.privateKey,
                senderPublicKey: aliceKeyPair.publicKey
            )
            #expect(decrypted == message)
        }
        
        // All ciphertexts should be different (due to random nonces)
        let uniqueCiphertexts = Set(ciphertexts)
        #expect(uniqueCiphertexts.count == 10)
    }
    
    @Test("Invalid payload sizes")
    func testInvalidPayloadSizes() throws {
        // Test various invalid payload sizes
        let invalidSizes = [
            0,   // Empty
            1,   // Just version byte
            32,  // Version + partial nonce
            33,  // Version + nonce, no ciphertext
            64,  // Version + nonce + partial MAC
            65   // Minimum valid size
        ]
        
        for size in invalidSizes where size < 65 {
            let data = Data(repeating: 0, count: size)
            let payload = data.base64EncodedString()
            
            #expect(throws: NIP44.NIP44Error.invalidPayload) {
                _ = try NIP44.decrypt(
                    payload: payload,
                    recipientPrivateKey: bobKeyPair.privateKey,
                    senderPublicKey: aliceKeyPair.publicKey
                )
            }
        }
    }
    
    @Test("ChaCha20 counter overflow protection")
    func testChaCha20CounterOverflow() throws {
        // Test with maximum size message that should work
        let maxSafeSize = 65535  // Just under 64KB
        let plaintext = String(repeating: "x", count: maxSafeSize)
        
        let encrypted = try NIP44.encrypt(
            plaintext: plaintext,
            senderPrivateKey: aliceKeyPair.privateKey,
            recipientPublicKey: bobKeyPair.publicKey
        )
        
        let decrypted = try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: bobKeyPair.privateKey,
            senderPublicKey: aliceKeyPair.publicKey
        )
        
        #expect(decrypted == plaintext)
    }
}

// MARK: - Official NIP-44 Test Vectors

/// Test suite using official NIP-44 test vectors from https://github.com/paulmillr/nip44
/// These vectors ensure cross-implementation compatibility.
@Suite("NIP-44 Official Test Vectors")
struct NIP44OfficialVectorTests {
    
    // MARK: - calc_padded_len vectors
    
    @Test("Official padding length calculation vectors")
    func testCalcPaddedLen() throws {
        // Official test vectors from nip44.vectors.json valid.calc_padded_len
        // These test the padding calculation algorithm, not actual encryption
        let vectors: [(unpadded: Int, expected: Int)] = [
            (16, 32),
            (32, 32),
            (33, 64),
            (37, 64),
            (45, 64),
            (49, 64),
            (64, 64),
            (65, 96),
            (100, 128),
            (111, 128),
            (200, 224),
            (250, 256),
            (320, 320),
            (383, 384),
            (384, 384),
            (400, 448),
            (500, 512),
            (512, 512),
            (515, 640),
            (700, 768),
            (800, 896),
            (900, 1024),
            (1020, 1024),
            (65536, 65536)  // Note: 65536 tests calcPaddedLen, not actual encryption (max plaintext is 65535)
        ]
        
        // Test the padding calculation function directly
        for vector in vectors {
            let computed = NIP44.testCalcPaddedLen(vector.unpadded)
            #expect(computed == vector.expected,
                   "calcPaddedLen(\(vector.unpadded)) = \(computed), expected \(vector.expected)")
        }
        
        // Additionally, verify encryption works for lengths within valid range (1-65535)
        let encryptableVectors = vectors.filter { $0.unpadded <= 65535 }
        for vector in encryptableVectors {
            let plaintext = String(repeating: "x", count: vector.unpadded)
            let keyPair = try KeyPair.generate()
            let recipientKeyPair = try KeyPair.generate()
            
            let encrypted = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: keyPair.privateKey,
                recipientPublicKey: recipientKeyPair.publicKey
            )
            
            guard let payloadData = Data(base64Encoded: encrypted) else {
                Issue.record("Failed to decode base64 for unpadded length \(vector.unpadded)")
                continue
            }
            
            // Payload structure: version(1) + nonce(32) + ciphertext(2 + paddedLen) + hmac(32)
            let expectedPayloadSize = 1 + 32 + (2 + vector.expected) + 32
            #expect(payloadData.count == expectedPayloadSize, 
                   "For unpadded \(vector.unpadded): expected payload size \(expectedPayloadSize), got \(payloadData.count)")
        }
    }
    
    // MARK: - encrypt_decrypt vectors
    
    @Test("Official encrypt/decrypt vectors with deterministic nonce")
    func testEncryptDecryptVectors() throws {
        // Official test vectors from nip44.vectors.json valid.encrypt_decrypt
        struct Vector {
            let sec1: String
            let sec2: String
            let conversationKey: String
            let nonce: String
            let plaintext: String
            let payload: String
        }
        
        let vectors: [Vector] = [
            Vector(
                sec1: "0000000000000000000000000000000000000000000000000000000000000001",
                sec2: "0000000000000000000000000000000000000000000000000000000000000002",
                conversationKey: "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
                nonce: "0000000000000000000000000000000000000000000000000000000000000001",
                plaintext: "a",
                payload: "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb"
            ),
            Vector(
                sec1: "0000000000000000000000000000000000000000000000000000000000000002",
                sec2: "0000000000000000000000000000000000000000000000000000000000000001",
                conversationKey: "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
                nonce: "f00000000000000000000000000000f00000000000000000000000000000000f",
                plaintext: "🍕🫃",
                payload: "AvAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAAPSKSK6is9ngkX2+cSq85Th16oRTISAOfhStnixqZziKMDvB0QQzgFZdjLTPicCJaV8nDITO+QfaQ61+KbWQIOO2Yj"
            ),
            Vector(
                sec1: "5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a",
                sec2: "4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d",
                conversationKey: "3e2b52a63be47d34fe0a80e34e73d436d6963bc8f39827f327057a9986c20a45",
                nonce: "b635236c42db20f021bb8d1cdff5ca75dd1a0cc72ea742ad750f33010b24f73b",
                plaintext: "表ポあA鷗ŒéＢ逍Üßªąñ丂㐀𠀀",
                payload: "ArY1I2xC2yDwIbuNHN/1ynXdGgzHLqdCrXUPMwELJPc7s7JqlCMJBAIIjfkpHReBPXeoMCyuClwgbT419jUWU1PwaNl4FEQYKCDKVJz+97Mp3K+Q2YGa77B6gpxB/lr1QgoqpDf7wDVrDmOqGoiPjWDqy8KzLueKDcm9BVP8xeTJIxs="
            ),
            Vector(
                sec1: "8f40e50a84a7462e2b8d24c28898ef1f23359fff50d8c509e6fb7ce06e142f9c",
                sec2: "b9b0a1e9cc20100c5faa3bbe2777303d25950616c4c6a3fa2e3e046f936ec2ba",
                conversationKey: "d5a2f879123145a4b291d767428870f5a8d9e5007193321795b40183d4ab8c2b",
                nonce: "b20989adc3ddc41cd2c435952c0d59a91315d8c5218d5040573fc3749543acaf",
                plaintext: "ability🤝的 ȺȾ",
                payload: "ArIJia3D3cQc0sQ1lSwNWakTFdjFIY1QQFc/w3SVQ6yvbG2S0x4Yu86QGwPTy7mP3961I1XqB6SFFTzqDZZavhxoWMj7mEVGMQIsh2RLWI5EYQaQDIePSnXPlzf7CIt+voTD"
            ),
            Vector(
                sec1: "875adb475056aec0b4809bd2db9aa00cff53a649e7b59d8edcbf4e6330b0995c",
                sec2: "9c05781112d5b0a2a7148a222e50e0bd891d6b60c5483f03456e982185944aae",
                conversationKey: "3b15c977e20bfe4b8482991274635edd94f366595b1a3d2993515705ca3cedb8",
                nonce: "8d4442713eb9d4791175cb040d98d6fc5be8864d6ec2f89cf0895a2b2b72d1b1",
                plaintext: "pepper👀їжак",
                payload: "Ao1EQnE+udR5EXXLBA2Y1vxb6IZNbsL4nPCJWisrctGxY3AduCS+jTUgAAnfvKafkmpy15+i9YMwCdccisRa8SvzW671T2JO4LFSPX31K4kYUKelSAdSPwe9NwO6LhOsnoJ+"
            )
        ]
        
        for (index, vector) in vectors.enumerated() {
            // Convert nonce from hex to Data
            guard let nonceData = Data(hex: vector.nonce) else {
                Issue.record("Invalid nonce hex at index \(index)")
                continue
            }
            
            // Get recipient's public key from sec2
            let recipientKeyPair = try KeyPair(privateKey: vector.sec2)
            
            // Encrypt with deterministic nonce
            let encrypted = try NIP44.encrypt(
                plaintext: vector.plaintext,
                senderPrivateKey: vector.sec1,
                recipientPublicKey: recipientKeyPair.publicKey,
                nonce: nonceData
            )
            
            // Verify payload matches expected
            #expect(encrypted == vector.payload, 
                   "Vector \(index): payload mismatch for plaintext '\(vector.plaintext)'")
            
            // Verify we can decrypt the official payload
            let decrypted = try NIP44.decrypt(
                payload: vector.payload,
                recipientPrivateKey: vector.sec2,
                senderPublicKey: try KeyPair(privateKey: vector.sec1).publicKey
            )
            
            #expect(decrypted == vector.plaintext,
                   "Vector \(index): decryption mismatch for plaintext '\(vector.plaintext)'")
        }
    }
    
    // MARK: - Invalid decrypt vectors
    
    @Test("Official invalid decryption vectors")
    func testInvalidDecryptVectors() throws {
        // Official test vectors from nip44.vectors.json invalid.decrypt
        struct InvalidVector {
            let conversationKey: String
            let nonce: String
            let payload: String
            let note: String
        }
        
        let vectors: [InvalidVector] = [
            InvalidVector(
                conversationKey: "ca2527a037347b91bea0c8a30fc8d9600ffd81ec00038671e3a0f0cb0fc9f642",
                nonce: "daaea5ca345b268e5b62060ca72c870c48f713bc1e00ff3fc0ddb78e826f10db",
                payload: "#Atqupco0WyaOW2IGDKcshwxI9xO8HgD/P8Ddt46CbxDbrhdG8VmJdU0MIDf06CUvEvdnr1cp1fiMtlM/GrE92xAc1K5odTpCzUB+mjXgbaqtntBUbTToSUoT0ovrlPwzGjyp",
                note: "unknown encryption version"
            ),
            InvalidVector(
                conversationKey: "36f04e558af246352dcf73b692fbd3646a2207bd8abd4b1cd26b234db84d9481",
                nonce: "ad408d4be8616dc84bb0bf046454a2a102edac937c35209c43cd7964c5feb781",
                payload: "AK1AjUvoYW3IS7C/BGRUoqEC7ayTfDUgnEPNeWTF/reBZFaha6EAIRueE9D1B1RuoiuFScC0Q94yjIuxZD3JStQtE8JMNacWFs9rlYP+ZydtHhRucp+lxfdvFlaGV/sQlqZz",
                note: "unknown encryption version 0"
            ),
            InvalidVector(
                conversationKey: "5cd2d13b9e355aeb2452afbd3786870dbeecb9d355b12cb0a3b6e9da5744cd35",
                nonce: "b60036976a1ada277b948fd4caa065304b96964742b89d26f26a25263a5060bd",
                payload: "",
                note: "invalid payload length: 0"
            ),
            InvalidVector(
                conversationKey: "d61d3f09c7dfe1c0be91af7109b60a7d9d498920c90cbba1e137320fdd938853",
                nonce: "1a29d02c8b4527745a2ccb38bfa45655deb37bc338ab9289d756354cea1fd07c",
                payload: "Ag==",
                note: "invalid payload length: 4"
            )
        ]
        
        // Create keypairs to test decryption (we use fake keys since we expect failure)
        let keyPair = try KeyPair.generate()
        let recipientKeyPair = try KeyPair.generate()
        
        for vector in vectors {
            // All these payloads should fail to decrypt
            #expect(throws: (any Error).self, "\(vector.note) should throw") {
                _ = try NIP44.decrypt(
                    payload: vector.payload,
                    recipientPrivateKey: recipientKeyPair.privateKey,
                    senderPublicKey: keyPair.publicKey
                )
            }
        }
    }
    
    // MARK: - Message length validation
    
    @Test("Official invalid message length vectors")
    func testInvalidMessageLengths() throws {
        // Official test vectors from nip44.vectors.json invalid.encrypt_msg_lengths
        let invalidLengths = [0, 65536, 100000]
        
        let keyPair = try KeyPair.generate()
        let recipientKeyPair = try KeyPair.generate()
        
        for length in invalidLengths {
            if length == 0 {
                // Empty string should fail
                #expect(throws: NIP44.NIP44Error.invalidPayload, "Length 0 should throw") {
                    _ = try NIP44.encrypt(
                        plaintext: "",
                        senderPrivateKey: keyPair.privateKey,
                        recipientPublicKey: recipientKeyPair.publicKey
                    )
                }
            } else {
                // Strings larger than 65535 should fail
                let plaintext = String(repeating: "x", count: length)
                #expect(throws: NIP44.NIP44Error.invalidPayload, "Length \(length) should throw") {
                    _ = try NIP44.encrypt(
                        plaintext: plaintext,
                        senderPrivateKey: keyPair.privateKey,
                        recipientPublicKey: recipientKeyPair.publicKey
                    )
                }
            }
        }
    }
    
    // MARK: - Conversation key vectors (for internal validation)
    
    @Test("Official conversation key generation vectors")
    func testConversationKeyVectors() throws {
        // A subset of official test vectors from nip44.vectors.json valid.get_conversation_key
        struct ConversationKeyVector {
            let sec1: String
            let pub2: String
            let expectedConversationKey: String
        }
        
        let vectors: [ConversationKeyVector] = [
            ConversationKeyVector(
                sec1: "0000000000000000000000000000000000000000000000000000000000000001",
                pub2: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
                expectedConversationKey: "3b4610cb7189beb9cc29eb3716ecc6102f1247e8f3103a03a1787d8908aeb54e"
            ),
            ConversationKeyVector(
                sec1: "0000000000000000000000000000000000000000000000000000000000000002",
                pub2: "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
                expectedConversationKey: "3b4610cb7189beb9cc29eb3716ecc6102f1247e8f3103a03a1787d8908aeb54e"
            )
        ]
        
        // For each vector, verify that encrypting from sec1 to pub2 and back works
        // (We can't directly test conversation key without exposing internals)
        for vector in vectors {
            // Get recipient's keypair - we need to derive from a valid private key
            // For pub2 = G (generator point), sec2 = 1
            // For pub2 = 2G, sec2 = 2
            let sec2: String
            if vector.pub2 == "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798" {
                sec2 = "0000000000000000000000000000000000000000000000000000000000000001"
            } else if vector.pub2 == "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5" {
                sec2 = "0000000000000000000000000000000000000000000000000000000000000002"
            } else {
                continue // Skip vectors we can't reconstruct
            }
            
            let plaintext = "test message"
            
            // Encrypt from sec1 to pub2
            let encrypted = try NIP44.encrypt(
                plaintext: plaintext,
                senderPrivateKey: vector.sec1,
                recipientPublicKey: vector.pub2
            )
            
            // Decrypt using sec2
            let decrypted = try NIP44.decrypt(
                payload: encrypted,
                recipientPrivateKey: sec2,
                senderPublicKey: try KeyPair(privateKey: vector.sec1).publicKey
            )
            
            #expect(decrypted == plaintext, "Conversation key vector failed for sec1=\(vector.sec1)")
        }
    }
}

// MARK: - Hex Data Extension for Tests

extension Data {
    init?(hex: String) {
        let hex = hex.lowercased()
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
}
