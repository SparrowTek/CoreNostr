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
        aliceKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000001")
        bobKeyPair = try KeyPair(privateKey: "0000000000000000000000000000000000000000000000000000000000000002")
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
        #expect(throws: NIP44.NIP44Error.invalidPrivateKey) {
            _ = try NIP44.encrypt(
                plaintext: "Test",
                senderPrivateKey: "invalid-key",
                recipientPublicKey: bobKeyPair.publicKey
            )
        }
    }
    
    @Test("Invalid public key throws")
    func testInvalidPublicKeyThrows() throws {
        #expect(throws: NIP44.NIP44Error.invalidPrivateKey) {
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
}