import Testing
import Foundation
@testable import CoreNostr

@Suite("Basic CoreNostr Tests")
struct BasicTests {
    
    @Test("Generate KeyPair")
    func testGenerateKeyPair() throws {
        let keyPair = try KeyPair.generate()
        #expect(keyPair.publicKey.count == 64)
        #expect(keyPair.privateKey.count == 64)
    }
    
    @Test("Create text note")
    func testCreateTextNote() throws {
        let keyPair = try KeyPair.generate()
        let event = try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: "Hello, Nostr!"
        )
        
        #expect(event.kind == EventKind.textNote.rawValue)
        #expect(event.content == "Hello, Nostr!")
        #expect(event.pubkey == keyPair.publicKey)
        #expect(event.id.count == 64)
        #expect(event.sig.count == 128)
    }
    
    @Test("Create and verify event")
    func testCreateAndVerifyEvent() throws {
        let keyPair = try KeyPair.generate()
        let event = try CoreNostr.createEvent(
            keyPair: keyPair,
            kind: .textNote,
            content: "Test event",
            tags: []
        )
        
        let isValid = try CoreNostr.verifyEvent(event)
        #expect(isValid == true)
    }
    
    @Test("Create metadata event")
    func testCreateMetadataEvent() throws {
        let keyPair = try KeyPair.generate()
        let event = try CoreNostr.createMetadataEvent(
            keyPair: keyPair,
            name: "Test User",
            about: "A test user",
            picture: "https://example.com/pic.jpg"
        )
        
        #expect(event.kind == EventKind.setMetadata.rawValue)
        #expect(event.content.contains("Test User"))
    }
    
    @Test("SHA256 hashing")
    func testSHA256() {
        let data = Data("Hello, Nostr!".utf8)
        let hash = NIP06.sha256(data)
        
        #expect(hash.count == 32)
        #expect(hash.hex == "526129966c2517ba9015ac2835cda4e02f1054aec4fb57dfae6ff894b0aae69a")
    }
    
    @Test("BIP39 mnemonic generation")
    func testMnemonicGeneration() throws {
        let mnemonic = try BIP39.generateMnemonic()
        let words = mnemonic.split(separator: " ")
        
        #expect(words.count == 24) // Default is 24 words
    }
    
    @Test("Key derivation from mnemonic")
    func testKeyDerivation() throws {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let keyPair = try NIP06.deriveKeyPair(from: mnemonic)
        
        #expect(keyPair.privateKey.count == 64)
        #expect(keyPair.publicKey.count == 64)
    }
}