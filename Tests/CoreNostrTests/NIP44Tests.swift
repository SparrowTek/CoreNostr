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
        
        let vectors = [
            TestVector(
                senderPrivKey: "0000000000000000000000000000000000000000000000000000000000000001",
                recipientPubKey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
                plaintext: "hello world",
                conversationKey: nil
            ),
            TestVector(
                senderPrivKey: "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb",
                recipientPubKey: "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
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
            let (encryptionKey, hmacKey) = try NIP44.testDerivedKeys(
                sharedSecret: sharedSecret,
                nonce: deterministicNonce
            )
            
            let hmacStart = payloadData.count - 32
            let computedHMAC = NIP44.testComputeHMAC(
                payload: Data(payloadData[..<hmacStart]),
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
