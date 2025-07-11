import Testing
import Foundation
@testable import CoreNostr

// MARK: - Crypto Tests
@Test func keyPairGeneration() async throws {
    let keyPair = try KeyPair.generate()
    
    #expect(keyPair.privateKey.count == 64)
    #expect(keyPair.publicKey.count == 64)
    #expect(NostrCrypto.isValidPrivateKey(keyPair.privateKey))
    #expect(NostrCrypto.isValidPublicKey(keyPair.publicKey))
}

@Test func keyPairFromPrivateKey() async throws {
    let privateKeyHex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    let keyPair = try KeyPair(privateKey: privateKeyHex)
    
    #expect(keyPair.privateKey == privateKeyHex)
    #expect(keyPair.publicKey.count == 64)
    #expect(NostrCrypto.isValidPublicKey(keyPair.publicKey))
}

@Test func eventSigning() async throws {
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "Hello, Nostr!"
    )
    
    let signedEvent = try keyPair.signEvent(event)
    
    #expect(signedEvent.sig.count == 128)
    #expect(NostrCrypto.isValidSignature(signedEvent.sig))
    #expect(signedEvent.pubkey == keyPair.publicKey)
    #expect(signedEvent.content == "Hello, Nostr!")
}

@Test func eventVerification() async throws {
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "Hello, Nostr!"
    )
    
    let signedEvent = try keyPair.signEvent(event)
    let isValid = try KeyPair.verifyEvent(signedEvent)
    
    #expect(isValid)
}

@Test func eventIdCalculation() async throws {
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "Hello, Nostr!"
    )
    
    let eventId = event.calculateId()
    
    #expect(eventId.count == 64)
    #expect(NostrCrypto.isValidEventId(eventId))
}

// MARK: - Model Tests
@Test func nostrEventCreation() async throws {
    let pubkey = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    let event = NostrEvent(
        pubkey: pubkey,
        kind: 1,
        tags: [["e", "event123"], ["p", "user456"]],
        content: "Test content"
    )
    
    #expect(event.pubkey == pubkey)
    #expect(event.kind == 1)
    #expect(event.tags.count == 2)
    #expect(event.content == "Test content")
    #expect(event.isTextNote)
    #expect(!event.isMetadata)
}

@Test func nostrEventSerialization() async throws {
    let event = NostrEvent(
        id: "test123",
        pubkey: "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        createdAt: 1234567890,
        kind: 1,
        tags: [["e", "event123"]],
        content: "Test content",
        sig: "testsig"
    )
    
    let serialized = event.serializedForSigning()
    
    #expect(serialized.contains("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"))
    #expect(serialized.contains("1234567890"))
    #expect(serialized.contains("Test content"))
}

@Test func eventKindEnum() async throws {
    #expect(EventKind.setMetadata.rawValue == 0)
    #expect(EventKind.textNote.rawValue == 1)
    #expect(EventKind.recommendServer.rawValue == 2)
    
    let event = NostrEvent(
        pubkey: "test",
        kind: EventKind.textNote.rawValue,
        content: "test"
    )
    
    #expect(event.eventKind == .textNote)
    #expect(event.isTextNote)
}

@Test func eventTagParsing() async throws {
    let event = NostrEvent(
        pubkey: "test",
        kind: 1,
        tags: [
            ["e", "event123", "relay1"],
            ["p", "user456"],
            ["t", "hashtag"]
        ],
        content: "test"
    )
    
    #expect(event.referencedEvents == ["event123"])
    #expect(event.mentionedUsers == ["user456"])
}

// MARK: - Filter Tests
@Test func filterCreation() async throws {
    let since = Date(timeIntervalSince1970: 1234567890)
    let until = Date(timeIntervalSince1970: 1234567900)
    
    let filter = Filter(
        ids: ["event123"],
        authors: ["author456"],
        kinds: [1, 2],
        since: since,
        until: until,
        limit: 10
    )
    
    #expect(filter.ids == ["event123"])
    #expect(filter.authors == ["author456"])
    #expect(filter.kinds == [1, 2])
    #expect(filter.since == 1234567890)
    #expect(filter.until == 1234567900)
    #expect(filter.limit == 10)
}

@Test func filterConvenience() async throws {
    let authors = ["author123"]
    let since = Date()
    
    let textNotesFilter = Filter.textNotes(authors: authors, since: since, limit: 20)
    #expect(textNotesFilter.kinds == [1])
    #expect(textNotesFilter.authors == authors)
    #expect(textNotesFilter.limit == 20)
    
    let metadataFilter = Filter.metadata(authors: authors, limit: 5)
    #expect(metadataFilter.kinds == [0])
    #expect(metadataFilter.authors == authors)
    #expect(metadataFilter.limit == 5)
    
    let repliesFilter = Filter.replies(to: "event123", limit: 10)
    #expect(repliesFilter.kinds == [1])
    #expect(repliesFilter.e == ["event123"])
    #expect(repliesFilter.limit == 10)
}

// MARK: - Network Message Tests
@Test func clientMessageEncoding() async throws {
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "Test message"
    )
    let signedEvent = try keyPair.signEvent(event)
    
    let eventMessage = ClientMessage.event(signedEvent)
    let eventJson = try eventMessage.encode()
    #expect(eventJson.starts(with: "[\"EVENT\""))
    
    let filter = Filter(kinds: [1], limit: 10)
    let reqMessage = ClientMessage.req(subscriptionId: "sub1", filters: [filter])
    let reqJson = try reqMessage.encode()
    #expect(reqJson.starts(with: "[\"REQ\",\"sub1\""))
    
    let closeMessage = ClientMessage.close(subscriptionId: "sub1")
    let closeJson = try closeMessage.encode()
    #expect(closeJson == "[\"CLOSE\",\"sub1\"]")
}

@Test func relayMessageDecoding() async throws {
    let eventJson = "[\"EVENT\",\"sub1\",{\"id\":\"abc123\",\"pubkey\":\"def456\",\"created_at\":1234567890,\"kind\":1,\"tags\":[],\"content\":\"Hello\",\"sig\":\"signature123\"}]"
    let eventMessage = try RelayMessage.decode(from: eventJson)
    
    if case .event(let subId, let event) = eventMessage {
        #expect(subId == "sub1")
        #expect(event.id == "abc123")
        #expect(event.content == "Hello")
    } else {
        #expect(Bool(false), "Expected event message")
    }
    
    let okJson = "[\"OK\",\"event123\",true,\"success\"]"
    let okMessage = try RelayMessage.decode(from: okJson)
    
    if case .ok(let eventId, let accepted, let message) = okMessage {
        #expect(eventId == "event123")
        #expect(accepted == true)
        #expect(message == "success")
    } else {
        #expect(Bool(false), "Expected OK message")
    }
    
    let eoseJson = "[\"EOSE\",\"sub1\"]"
    let eoseMessage = try RelayMessage.decode(from: eoseJson)
    
    if case .eose(let subId) = eoseMessage {
        #expect(subId == "sub1")
    } else {
        #expect(Bool(false), "Expected EOSE message")
    }
}

// MARK: - CoreNostr API Tests
@Test func coreNostrAPI() async throws {
    let keyPair = try CoreNostr.createKeyPair()
    #expect(keyPair.privateKey.count == 64)
    #expect(keyPair.publicKey.count == 64)
    
    let textNote = try CoreNostr.createTextNote(
        keyPair: keyPair,
        content: "Hello, world!",
        replyTo: "event123",
        mentionedUsers: ["user456"]
    )
    
    #expect(textNote.content == "Hello, world!")
    #expect(textNote.isTextNote)
    #expect(textNote.referencedEvents == ["event123"])
    #expect(textNote.mentionedUsers == ["user456"])
    
    let isValid = try CoreNostr.verifyEvent(textNote)
    #expect(isValid)
}

@Test func metadataEvent() async throws {
    let keyPair = try CoreNostr.createKeyPair()
    
    let metadata = try CoreNostr.createMetadataEvent(
        keyPair: keyPair,
        name: "Test User",
        about: "This is a test user",
        picture: "https://example.com/avatar.png"
    )
    
    #expect(metadata.isMetadata)
    #expect(metadata.content.contains("Test User"))
    #expect(metadata.content.contains("This is a test user"))
    #expect(metadata.content.contains("https://example.com/avatar.png") || metadata.content.contains("https:\\/\\/example.com\\/avatar.png"))
    
    let isValid = try CoreNostr.verifyEvent(metadata)
    #expect(isValid)
}

// MARK: - Validation Tests
@Test func validationFunctions() async throws {
    #expect(NostrCrypto.isValidEventId("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"))
    #expect(!NostrCrypto.isValidEventId("invalid"))
    
    #expect(NostrCrypto.isValidPublicKey("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"))
    #expect(!NostrCrypto.isValidPublicKey("invalid"))
    
    #expect(NostrCrypto.isValidPrivateKey("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"))
    #expect(!NostrCrypto.isValidPrivateKey("invalid"))
    
    let validSig = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    #expect(NostrCrypto.isValidSignature(validSig))
    #expect(!NostrCrypto.isValidSignature("invalid"))
}

// MARK: - Error Handling Tests
@Test func errorHandling() async throws {
    do {
        _ = try KeyPair(privateKey: "invalid")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    do {
        let invalidJson = "[\"INVALID\",\"message\"]"
        _ = try RelayMessage.decode(from: invalidJson)
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
}
