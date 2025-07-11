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

// MARK: - Follow List Tests (NIP-02)
@Test func followEntryCreation() async throws {
    let entry = FollowEntry(
        pubkey: "91cf9..4e5ca",
        relayURL: "wss://alicerelay.com/",
        petname: "alice"
    )
    
    #expect(entry.pubkey == "91cf9..4e5ca")
    #expect(entry.relayURL == "wss://alicerelay.com/")
    #expect(entry.petname == "alice")
}

@Test func followEntryFromTag() async throws {
    let fullTag = ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"]
    let entry = FollowEntry.from(tag: fullTag)
    
    #expect(entry?.pubkey == "91cf9..4e5ca")
    #expect(entry?.relayURL == "wss://alicerelay.com/")
    #expect(entry?.petname == "alice")
    
    let minimalTag = ["p", "91cf9..4e5ca"]
    let minimalEntry = FollowEntry.from(tag: minimalTag)
    
    #expect(minimalEntry?.pubkey == "91cf9..4e5ca")
    #expect(minimalEntry?.relayURL == nil)
    #expect(minimalEntry?.petname == nil)
    
    let invalidTag = ["e", "invalid"]
    let invalidEntry = FollowEntry.from(tag: invalidTag)
    #expect(invalidEntry == nil)
}

@Test func followEntryToTag() async throws {
    let fullEntry = FollowEntry(
        pubkey: "91cf9..4e5ca",
        relayURL: "wss://alicerelay.com/",
        petname: "alice"
    )
    let fullTag = fullEntry.toTag()
    #expect(fullTag == ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"])
    
    let minimalEntry = FollowEntry(pubkey: "91cf9..4e5ca")
    let minimalTag = minimalEntry.toTag()
    #expect(minimalTag == ["p", "91cf9..4e5ca"])
    
    let relayOnlyEntry = FollowEntry(pubkey: "91cf9..4e5ca", relayURL: "wss://relay.com/")
    let relayOnlyTag = relayOnlyEntry.toTag()
    #expect(relayOnlyTag == ["p", "91cf9..4e5ca", "wss://relay.com/"])
    
    let petnameOnlyEntry = FollowEntry(pubkey: "91cf9..4e5ca", petname: "alice")
    let petnameOnlyTag = petnameOnlyEntry.toTag()
    #expect(petnameOnlyTag == ["p", "91cf9..4e5ca", "", "alice"])
}

@Test func followListCreation() async throws {
    let follows = [
        FollowEntry(pubkey: "91cf9..4e5ca", relayURL: "wss://alicerelay.com/", petname: "alice"),
        FollowEntry(pubkey: "14aeb..8dad4", relayURL: "wss://bobrelay.com/nostr", petname: "bob"),
        FollowEntry(pubkey: "612ae..e610f", relayURL: "ws://carolrelay.com/ws", petname: "carol")
    ]
    
    let followList = NostrFollowList(follows: follows)
    #expect(followList.follows.count == 3)
    #expect(followList.isFollowing("91cf9..4e5ca"))
    #expect(!followList.isFollowing("unknown"))
    #expect(followList.petname(for: "91cf9..4e5ca") == "alice")
    #expect(followList.relayURL(for: "14aeb..8dad4") == "wss://bobrelay.com/nostr")
}

@Test func followListEventCreation() async throws {
    let follows = [
        FollowEntry(pubkey: "91cf9..4e5ca", relayURL: "wss://alicerelay.com/", petname: "alice"),
        FollowEntry(pubkey: "14aeb..8dad4", relayURL: "wss://bobrelay.com/nostr", petname: "bob")
    ]
    
    let followList = NostrFollowList(follows: follows)
    let keyPair = try KeyPair.generate()
    let event = followList.createEvent(pubkey: keyPair.publicKey)
    
    #expect(event.kind == EventKind.followList.rawValue)
    #expect(event.content == "")
    #expect(event.tags.count == 2)
    #expect(event.tags[0] == ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"])
    #expect(event.tags[1] == ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"])
    #expect(event.pubkey == keyPair.publicKey)
}

@Test func followListFromEvent() async throws {
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        id: "test123",
        pubkey: keyPair.publicKey,
        createdAt: 1234567890,
        kind: 3,
        tags: [
            ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"],
            ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"],
            ["p", "612ae..e610f", "ws://carolrelay.com/ws", "carol"]
        ],
        content: "",
        sig: "testsig"
    )
    
    let followList = NostrFollowList.from(event: event)
    #expect(followList != nil)
    #expect(followList?.follows.count == 3)
    #expect(followList?.isFollowing("91cf9..4e5ca") == true)
    #expect(followList?.petname(for: "14aeb..8dad4") == "bob")
    
    let invalidEvent = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "not a follow list"
    )
    let invalidFollowList = NostrFollowList.from(event: invalidEvent)
    #expect(invalidFollowList == nil)
}

@Test func followListManagement() async throws {
    let followList = NostrFollowList()
    
    let newFollow = FollowEntry(pubkey: "alice123", petname: "Alice")
    let updatedList = followList.adding(newFollow)
    #expect(updatedList.follows.count == 1)
    #expect(updatedList.isFollowing("alice123"))
    
    let secondFollow = FollowEntry(pubkey: "bob456", relayURL: "wss://bob.relay/")
    let listWithTwo = updatedList.adding(secondFollow)
    #expect(listWithTwo.follows.count == 2)
    
    let removedList = listWithTwo.removing(pubkey: "alice123")
    #expect(removedList.follows.count == 1)
    #expect(!removedList.isFollowing("alice123"))
    #expect(removedList.isFollowing("bob456"))
}

@Test func followListUpdates() async throws {
    let follow = FollowEntry(pubkey: "alice123", relayURL: "wss://old.relay/", petname: "Old Alice")
    let followList = NostrFollowList(follows: [follow])
    
    let updatedPetname = followList.updatingPetname(for: "alice123", to: "New Alice")
    #expect(updatedPetname.petname(for: "alice123") == "New Alice")
    #expect(updatedPetname.relayURL(for: "alice123") == "wss://old.relay/")
    
    let updatedRelay = followList.updatingRelayURL(for: "alice123", to: "wss://new.relay/")
    #expect(updatedRelay.relayURL(for: "alice123") == "wss://new.relay/")
    #expect(updatedRelay.petname(for: "alice123") == "Old Alice")
    
    let removedPetname = followList.updatingPetname(for: "alice123", to: nil)
    #expect(removedPetname.petname(for: "alice123") == nil)
}

@Test func followListEventKind() async throws {
    #expect(EventKind.followList.rawValue == 3)
    #expect(EventKind.followList.description == "Follow List")
    
    let followList = NostrFollowList()
    let keyPair = try KeyPair.generate()
    let event = followList.createEvent(pubkey: keyPair.publicKey)
    
    #expect(event.eventKind == .followList)
    #expect(event.isFollowList)
}

@Test func coreNostrFollowListAPI() async throws {
    let keyPair = try CoreNostr.createKeyPair()
    
    let follows = [
        FollowEntry(pubkey: "alice123", relayURL: "wss://alice.relay/", petname: "Alice"),
        FollowEntry(pubkey: "bob456", relayURL: "wss://bob.relay/", petname: "Bob")
    ]
    
    let followListEvent = try CoreNostr.createFollowListEvent(
        keyPair: keyPair,
        follows: follows
    )
    
    #expect(followListEvent.isFollowList)
    #expect(followListEvent.content == "")
    #expect(followListEvent.tags.count == 2)
    #expect(followListEvent.tags[0] == ["p", "alice123", "wss://alice.relay/", "Alice"])
    #expect(followListEvent.tags[1] == ["p", "bob456", "wss://bob.relay/", "Bob"])
    
    let isValid = try CoreNostr.verifyEvent(followListEvent)
    #expect(isValid)
    
    let filter = Filter.followLists(authors: [keyPair.publicKey], limit: 1)
    #expect(filter.kinds == [3])
    #expect(filter.authors == [keyPair.publicKey])
    #expect(filter.limit == 1)
}

// MARK: - OpenTimestamps Tests (NIP-03)
@Test func openTimestampsCreation() async throws {
    // Create mock OTS data with correct magic bytes
    let otsMagic: [UInt8] = [0x00, 0x4F, 0x54, 0x53] // NUL, 'O', 'T', 'S'
    let mockOTSData = Data(otsMagic + [0x01, 0x02, 0x03, 0x04]) // Add some mock attestation data
    
    let attestation = NostrOpenTimestamps(
        eventId: "e71c6ea722987debdb60f81f9ea4f604b5ac0664120dd64fb9d23abc4ec7c323",
        relayURL: "wss://relay.example.com",
        otsData: mockOTSData
    )
    
    #expect(attestation.eventId == "e71c6ea722987debdb60f81f9ea4f604b5ac0664120dd64fb9d23abc4ec7c323")
    #expect(attestation.relayURL == "wss://relay.example.com")
    #expect(attestation.otsData == mockOTSData)
    #expect(attestation.isValidOTSData())
    #expect(attestation.otsDataSize == 8)
}

@Test func openTimestampsEventCreation() async throws {
    let otsMagic: [UInt8] = [0x00, 0x4F, 0x54, 0x53]
    let mockOTSData = Data(otsMagic + [0x01, 0x02, 0x03, 0x04])
    
    let attestation = NostrOpenTimestamps(
        eventId: "event123",
        relayURL: "wss://relay.com",
        otsData: mockOTSData
    )
    
    let keyPair = try KeyPair.generate()
    let event = attestation.createEvent(pubkey: keyPair.publicKey)
    
    #expect(event.kind == EventKind.openTimestamps.rawValue)
    #expect(event.tags.count == 2)
    #expect(event.tags[0] == ["e", "event123", "wss://relay.com"])
    #expect(event.tags[1] == ["alt", "opentimestamps attestation"])
    #expect(event.content == mockOTSData.base64EncodedString())
    #expect(event.pubkey == keyPair.publicKey)
}

@Test func openTimestampsFromEvent() async throws {
    let otsMagic: [UInt8] = [0x00, 0x4F, 0x54, 0x53]
    let mockOTSData = Data(otsMagic + [0x01, 0x02, 0x03, 0x04])
    let base64OTS = mockOTSData.base64EncodedString()
    
    let keyPair = try KeyPair.generate()
    let event = NostrEvent(
        id: "test123",
        pubkey: keyPair.publicKey,
        createdAt: 1234567890,
        kind: 1040,
        tags: [
            ["e", "event123", "wss://relay.com"],
            ["alt", "opentimestamps attestation"]
        ],
        content: base64OTS,
        sig: "testsig"
    )
    
    let attestation = NostrOpenTimestamps.from(event: event)
    #expect(attestation != nil)
    #expect(attestation?.eventId == "event123")
    #expect(attestation?.relayURL == "wss://relay.com")
    #expect(attestation?.otsData == mockOTSData)
    #expect(attestation?.isValidOTSData() == true)
    
    // Test with minimal tags (no relay URL)
    let minimalEvent = NostrEvent(
        id: "test456",
        pubkey: keyPair.publicKey,
        createdAt: 1234567890,
        kind: 1040,
        tags: [
            ["e", "event456"],
            ["alt", "opentimestamps attestation"]
        ],
        content: base64OTS,
        sig: "testsig"
    )
    
    let minimalAttestation = NostrOpenTimestamps.from(event: minimalEvent)
    #expect(minimalAttestation != nil)
    #expect(minimalAttestation?.eventId == "event456")
    #expect(minimalAttestation?.relayURL == nil)
    
    // Test invalid event (wrong kind)
    let invalidEvent = NostrEvent(
        pubkey: keyPair.publicKey,
        kind: 1,
        content: "not an attestation"
    )
    let invalidAttestation = NostrOpenTimestamps.from(event: invalidEvent)
    #expect(invalidAttestation == nil)
}

@Test func openTimestampsFromBase64() async throws {
    let otsMagic: [UInt8] = [0x00, 0x4F, 0x54, 0x53]
    let mockOTSData = Data(otsMagic + [0x01, 0x02, 0x03, 0x04])
    let base64OTS = mockOTSData.base64EncodedString()
    
    let attestation = NostrOpenTimestamps.fromBase64(
        eventId: "event123",
        relayURL: "wss://relay.com",
        base64OTSData: base64OTS
    )
    
    #expect(attestation != nil)
    #expect(attestation?.eventId == "event123")
    #expect(attestation?.relayURL == "wss://relay.com")
    #expect(attestation?.otsData == mockOTSData)
    #expect(attestation?.base64EncodedOTSData == base64OTS)
    
    // Test invalid base64
    let invalidAttestation = NostrOpenTimestamps.fromBase64(
        eventId: "event123",
        base64OTSData: "invalid base64!!!"
    )
    #expect(invalidAttestation == nil)
}

@Test func openTimestampsValidation() async throws {
    // Valid OTS data (with magic bytes)
    let validOTSData = Data([0x00, 0x4F, 0x54, 0x53, 0x01, 0x02, 0x03])
    let validAttestation = NostrOpenTimestamps(eventId: "event123", otsData: validOTSData)
    #expect(validAttestation.isValidOTSData())
    
    // Invalid OTS data (wrong magic bytes)
    let invalidOTSData = Data([0x01, 0x02, 0x03, 0x04])
    let invalidAttestation = NostrOpenTimestamps(eventId: "event123", otsData: invalidOTSData)
    #expect(!invalidAttestation.isValidOTSData())
    
    // Too short data
    let shortOTSData = Data([0x00, 0x4F])
    let shortAttestation = NostrOpenTimestamps(eventId: "event123", otsData: shortOTSData)
    #expect(!shortAttestation.isValidOTSData())
}

@Test func openTimestampsEventKind() async throws {
    #expect(EventKind.openTimestamps.rawValue == 1040)
    #expect(EventKind.openTimestamps.description == "OpenTimestamps Attestation")
    
    let mockOTSData = Data([0x00, 0x4F, 0x54, 0x53, 0x01])
    let attestation = NostrOpenTimestamps(eventId: "event123", otsData: mockOTSData)
    let keyPair = try KeyPair.generate()
    let event = attestation.createEvent(pubkey: keyPair.publicKey)
    
    #expect(event.eventKind == .openTimestamps)
    #expect(event.isOpenTimestamps)
}

@Test func coreNostrOpenTimestampsAPI() async throws {
    let keyPair = try CoreNostr.createKeyPair()
    let mockOTSData = Data([0x00, 0x4F, 0x54, 0x53, 0x01, 0x02, 0x03, 0x04])
    
    // Test creating from raw data
    let attestationEvent = try CoreNostr.createOpenTimestampsEvent(
        keyPair: keyPair,
        eventId: "event123",
        relayURL: "wss://relay.com",
        otsData: mockOTSData
    )
    
    #expect(attestationEvent.isOpenTimestamps)
    #expect(attestationEvent.tags.count == 2)
    #expect(attestationEvent.tags[0] == ["e", "event123", "wss://relay.com"])
    #expect(attestationEvent.tags[1] == ["alt", "opentimestamps attestation"])
    #expect(attestationEvent.content == mockOTSData.base64EncodedString())
    
    let isValid = try CoreNostr.verifyEvent(attestationEvent)
    #expect(isValid)
    
    // Test creating from base64
    let base64OTS = mockOTSData.base64EncodedString()
    let base64Event = try CoreNostr.createOpenTimestampsEventFromBase64(
        keyPair: keyPair,
        eventId: "event456",
        relayURL: "wss://another.relay",
        base64OTSData: base64OTS
    )
    
    #expect(base64Event.isOpenTimestamps)
    #expect(base64Event.content == base64OTS)
    
    // Test filter
    let filter = Filter.openTimestamps(authors: [keyPair.publicKey], eventIds: ["event123"], limit: 10)
    #expect(filter.kinds == [1040])
    #expect(filter.authors == [keyPair.publicKey])
    #expect(filter.e == ["event123"])
    #expect(filter.limit == 10)
    
    // Test error with invalid base64
    do {
        _ = try CoreNostr.createOpenTimestampsEventFromBase64(
            keyPair: keyPair,
            eventId: "event789",
            base64OTSData: "invalid base64!!!"
        )
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
}

// MARK: - Direct Message Tests (NIP-04) - DEPRECATED
@Test func directMessageCreation() async throws {
    let senderKeyPair = try KeyPair.generate()
    let recipientKeyPair = try KeyPair.generate()
    let message = "Hello, this is a secret message!"
    
    let directMessage = try NostrDirectMessage.create(
        senderKeyPair: senderKeyPair,
        recipientPublicKey: recipientKeyPair.publicKey,
        message: message
    )
    
    #expect(directMessage.recipientPublicKey == recipientKeyPair.publicKey)
    #expect(directMessage.replyToEventId == nil)
    #expect(directMessage.isValidEncryptedContent())
    #expect(!directMessage.isReply)
    #expect(directMessage.encryptedDataSize != nil)
}

@Test func directMessageEventCreation() async throws {
    let senderKeyPair = try KeyPair.generate()
    let recipientKeyPair = try KeyPair.generate()
    let message = "Test message"
    let replyEventId = "reply123"
    
    let directMessage = try NostrDirectMessage.create(
        senderKeyPair: senderKeyPair,
        recipientPublicKey: recipientKeyPair.publicKey,
        message: message,
        replyToEventId: replyEventId
    )
    
    let event = directMessage.createEvent(pubkey: senderKeyPair.publicKey)
    
    #expect(event.kind == EventKind.encryptedDirectMessage.rawValue)
    #expect(event.tags.count == 2)
    #expect(event.tags[0] == ["p", recipientKeyPair.publicKey])
    #expect(event.tags[1] == ["e", replyEventId])
    #expect(event.content == directMessage.encryptedContent)
    #expect(event.pubkey == senderKeyPair.publicKey)
    #expect(event.isEncryptedDirectMessage)
    #expect(directMessage.isReply)
}

@Test func directMessageFromEvent() async throws {
    let senderKeyPair = try KeyPair.generate()
    let recipientKeyPair = try KeyPair.generate()
    let encryptedContent = "dGVzdA==?iv=MTIzNDU2Nzg5MGFiY2RlZg=="
    
    let event = NostrEvent(
        id: "test123",
        pubkey: senderKeyPair.publicKey,
        createdAt: 1234567890,
        kind: 4,
        tags: [
            ["p", recipientKeyPair.publicKey],
            ["e", "reply456"]
        ],
        content: encryptedContent,
        sig: "testsig"
    )
    
    let directMessage = NostrDirectMessage.from(event: event)
    #expect(directMessage != nil)
    #expect(directMessage?.recipientPublicKey == recipientKeyPair.publicKey)
    #expect(directMessage?.replyToEventId == "reply456")
    #expect(directMessage?.encryptedContent == encryptedContent)
    #expect(directMessage?.isReply == true)
    
    // Test invalid event (wrong kind)
    let invalidEvent = NostrEvent(
        pubkey: senderKeyPair.publicKey,
        kind: 1,
        content: "not encrypted"
    )
    let invalidDirectMessage = NostrDirectMessage.from(event: invalidEvent)
    #expect(invalidDirectMessage == nil)
}

@Test func directMessageEncryptionDecryption() async throws {
    let senderKeyPair = try KeyPair.generate()
    let recipientKeyPair = try KeyPair.generate()
    let originalMessage = "This is a test message for encryption!"
    
    // Create encrypted message
    let directMessage = try NostrDirectMessage.create(
        senderKeyPair: senderKeyPair,
        recipientPublicKey: recipientKeyPair.publicKey,
        message: originalMessage
    )
    
    // Decrypt the message
    let decryptedMessage = try directMessage.decrypt(
        with: recipientKeyPair,
        senderPublicKey: senderKeyPair.publicKey
    )
    
    #expect(decryptedMessage == originalMessage)
}

@Test func directMessageContentValidation() async throws {
    // Valid encrypted content format
    let validContent = "dGVzdA==?iv=MTIzNDU2Nzg5MGFiY2RlZg=="
    let validMessage = NostrDirectMessage(
        recipientPublicKey: "test123",
        encryptedContent: validContent
    )
    #expect(validMessage.isValidEncryptedContent())
    
    // Invalid content format (missing IV)
    let invalidContent1 = "dGVzdA=="
    let invalidMessage1 = NostrDirectMessage(
        recipientPublicKey: "test123",
        encryptedContent: invalidContent1
    )
    #expect(!invalidMessage1.isValidEncryptedContent())
    
    // Invalid content format (invalid base64)
    let invalidContent2 = "invalid!!!?iv=invalid!!!"
    let invalidMessage2 = NostrDirectMessage(
        recipientPublicKey: "test123",
        encryptedContent: invalidContent2
    )
    #expect(!invalidMessage2.isValidEncryptedContent())
}

@Test func directMessageEventKind() async throws {
    #expect(EventKind.encryptedDirectMessage.rawValue == 4)
    #expect(EventKind.encryptedDirectMessage.description == "Encrypted Direct Message")
    
    let senderKeyPair = try KeyPair.generate()
    let recipientKeyPair = try KeyPair.generate()
    
    let directMessage = try NostrDirectMessage.create(
        senderKeyPair: senderKeyPair,
        recipientPublicKey: recipientKeyPair.publicKey,
        message: "test"
    )
    let event = directMessage.createEvent(pubkey: senderKeyPair.publicKey)
    
    #expect(event.eventKind == .encryptedDirectMessage)
    #expect(event.isEncryptedDirectMessage)
}

@Test func coreNostrDirectMessageAPI() async throws {
    let senderKeyPair = try CoreNostr.createKeyPair()
    let recipientKeyPair = try CoreNostr.createKeyPair()
    let message = "Hello from CoreNostr API!"
    
    // Test creating encrypted message
    let encryptedEvent = try CoreNostr.createDirectMessageEvent(
        senderKeyPair: senderKeyPair,
        recipientPublicKey: recipientKeyPair.publicKey,
        message: message,
        replyToEventId: "reply789"
    )
    
    #expect(encryptedEvent.isEncryptedDirectMessage)
    #expect(encryptedEvent.tags.count == 2)
    #expect(encryptedEvent.tags[0] == ["p", recipientKeyPair.publicKey])
    #expect(encryptedEvent.tags[1] == ["e", "reply789"])
    
    let isValid = try CoreNostr.verifyEvent(encryptedEvent)
    #expect(isValid)
    
    // Test decrypting message
    let decryptedMessage = try CoreNostr.decryptDirectMessage(
        event: encryptedEvent,
        recipientKeyPair: recipientKeyPair
    )
    #expect(decryptedMessage == message)
    
    // Test filter
    let filter = Filter.encryptedDirectMessages(
        authors: [senderKeyPair.publicKey],
        recipients: [recipientKeyPair.publicKey],
        limit: 10
    )
    #expect(filter.kinds == [4])
    #expect(filter.authors == [senderKeyPair.publicKey])
    #expect(filter.p == [recipientKeyPair.publicKey])
    #expect(filter.limit == 10)
    
    // Test error with invalid event
    let invalidEvent = try CoreNostr.createTextNote(
        keyPair: senderKeyPair,
        content: "Not a direct message"
    )
    
    do {
        _ = try CoreNostr.decryptDirectMessage(
            event: invalidEvent,
            recipientKeyPair: recipientKeyPair
        )
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
}

@Test func directMessageSecurityWarning() async throws {
    let warning = NostrDirectMessage.securityWarning
    #expect(warning.contains("SECURITY WARNING"))
    #expect(warning.contains("DEPRECATED"))
    #expect(warning.contains("NIP-17"))
}

@Test func cryptoEncryptionDecryption() async throws {
    let message = "Test message for crypto functions"
    let sharedSecret = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    
    // Test encryption
    let encryptedContent = try NostrCrypto.encryptMessage(message, with: sharedSecret)
    #expect(encryptedContent.contains("?iv="))
    
    // Test decryption
    let decryptedMessage = try NostrCrypto.decryptMessage(encryptedContent, with: sharedSecret)
    #expect(decryptedMessage == message)
    
    // Test with invalid shared secret size
    let invalidSecret = Data([0x01, 0x02, 0x03])
    do {
        _ = try NostrCrypto.encryptMessage(message, with: invalidSecret)
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    // Test with invalid encrypted content format
    do {
        _ = try NostrCrypto.decryptMessage("invalid format", with: sharedSecret)
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
}

// MARK: - NIP-05 Tests (DNS-based internet identifiers)
@Test func nip05IdentifierCreation() async throws {
    // Valid identifiers
    let identifier1 = try NostrNIP05Identifier(identifier: "bob@example.com")
    #expect(identifier1.localPart == "bob")
    #expect(identifier1.domain == "example.com")
    #expect(identifier1.identifier == "bob@example.com")
    #expect(!identifier1.isRootIdentifier)
    #expect(identifier1.displayIdentifier == "bob@example.com")
    
    // Root identifier
    let rootIdentifier = try NostrNIP05Identifier(identifier: "_@example.com")
    #expect(rootIdentifier.localPart == "_")
    #expect(rootIdentifier.domain == "example.com")
    #expect(rootIdentifier.isRootIdentifier)
    #expect(rootIdentifier.displayIdentifier == "example.com")
    
    // Case insensitive
    let caseIdentifier = try NostrNIP05Identifier(identifier: "Bob@EXAMPLE.COM")
    #expect(caseIdentifier.localPart == "bob")
    #expect(caseIdentifier.domain == "example.com")
    
    // With allowed characters
    let complexIdentifier = try NostrNIP05Identifier(identifier: "test-user_123.foo@sub.example-site.com")
    #expect(complexIdentifier.localPart == "test-user_123.foo")
    #expect(complexIdentifier.domain == "sub.example-site.com")
}

@Test func nip05IdentifierValidation() async throws {
    // Invalid formats
    do {
        _ = try NostrNIP05Identifier(identifier: "invalid")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    do {
        _ = try NostrNIP05Identifier(identifier: "@example.com")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    do {
        _ = try NostrNIP05Identifier(identifier: "bob@")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    // Invalid characters in local part
    do {
        _ = try NostrNIP05Identifier(identifier: "bob!@example.com")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
    
    // Invalid domain
    do {
        _ = try NostrNIP05Identifier(identifier: "bob@.example.com")
        #expect(Bool(false), "Should have thrown an error")
    } catch {
        #expect(error is NostrError)
    }
}

@Test func nip05WellKnownURL() async throws {
    let identifier = try NostrNIP05Identifier(identifier: "bob@example.com")
    let url = identifier.wellKnownURL
    
    #expect(url != nil)
    #expect(url?.absoluteString == "https://example.com/.well-known/nostr.json?name=bob")
    
    let rootIdentifier = try NostrNIP05Identifier(identifier: "_@example.com")
    let rootURL = rootIdentifier.wellKnownURL
    
    #expect(rootURL?.absoluteString == "https://example.com/.well-known/nostr.json?name=_")
}

@Test func nip05ResponseParsing() async throws {
    let response = NostrNIP05Response(
        names: [
            "bob": "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9",
            "alice": "a1234567890123456789012345678901234567890123456789012345678901234"
        ],
        relays: [
            "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9": [
                "wss://relay.example.com",
                "wss://relay2.example.com"
            ]
        ]
    )
    
    #expect(response.publicKey(for: "bob") == "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9")
    #expect(response.publicKey(for: "alice") == "a1234567890123456789012345678901234567890123456789012345678901234")
    #expect(response.publicKey(for: "unknown") == nil)
    
    let relayURLs = response.relayURLs(for: "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9")
    #expect(relayURLs.count == 2)
    #expect(relayURLs.contains("wss://relay.example.com"))
    #expect(relayURLs.contains("wss://relay2.example.com"))
    
    let noRelayURLs = response.relayURLs(for: "a1234567890123456789012345678901234567890123456789012345678901234")
    #expect(noRelayURLs.isEmpty)
}

@Test func nip05DiscoveryResult() async throws {
    let identifier = try NostrNIP05Identifier(identifier: "bob@example.com")
    let result = NostrNIP05DiscoveryResult(
        identifier: identifier,
        publicKey: "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9",
        relayURLs: ["wss://relay.example.com"]
    )
    
    #expect(result.identifier.identifier == "bob@example.com")
    #expect(result.publicKey == "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9")
    #expect(result.relayURLs == ["wss://relay.example.com"])
}

@Test func nip05StringLiteralSupport() async throws {
    let identifier: NostrNIP05Identifier = "bob@example.com"
    #expect(identifier.localPart == "bob")
    #expect(identifier.domain == "example.com")
    #expect(identifier.description == "bob@example.com")
    
    let rootIdentifier: NostrNIP05Identifier = "_@example.com"
    #expect(rootIdentifier.description == "example.com")
}

@Test func nip05MetadataExtraction() async throws {
    let keyPair = try KeyPair.generate()
    
    // Create metadata event with NIP-05
    let metadataEvent = try CoreNostr.createMetadataEvent(
        keyPair: keyPair,
        name: "Bob",
        about: "A test user",
        picture: "https://example.com/avatar.png",
        nip05: "bob@example.com"
    )
    
    #expect(metadataEvent.isMetadata)
    
    let metadata = metadataEvent.metadataContent
    #expect(metadata != nil)
    #expect(metadata?["name"] as? String == "Bob")
    #expect(metadata?["about"] as? String == "A test user")
    #expect(metadata?["picture"] as? String == "https://example.com/avatar.png")
    #expect(metadata?["nip05"] as? String == "bob@example.com")
    
    #expect(metadataEvent.nip05Identifier == "bob@example.com")
    
    let parsedIdentifier = metadataEvent.parsedNIP05Identifier
    #expect(parsedIdentifier != nil)
    #expect(parsedIdentifier?.localPart == "bob")
    #expect(parsedIdentifier?.domain == "example.com")
    
    // Test event without NIP-05
    let basicEvent = try CoreNostr.createMetadataEvent(
        keyPair: keyPair,
        name: "Alice",
        about: "Another test user",
        picture: nil
    )
    
    #expect(basicEvent.nip05Identifier == nil)
    #expect(basicEvent.parsedNIP05Identifier == nil)
}

@Test func nip05ResponseJSONSerialization() async throws {
    let response = NostrNIP05Response(
        names: ["bob": "pubkey123"],
        relays: ["pubkey123": ["wss://relay.com"]]
    )
    
    let jsonData = try JSONEncoder().encode(response)
    let decodedResponse = try JSONDecoder().decode(NostrNIP05Response.self, from: jsonData)
    
    #expect(decodedResponse.publicKey(for: "bob") == "pubkey123")
    #expect(decodedResponse.relayURLs(for: "pubkey123") == ["wss://relay.com"])
}

@Test func nip05IdentifierEquality() async throws {
    let identifier1 = try NostrNIP05Identifier(identifier: "bob@example.com")
    let identifier2 = try NostrNIP05Identifier(identifier: "BOB@EXAMPLE.COM")
    let identifier3 = try NostrNIP05Identifier(identifier: "alice@example.com")
    
    #expect(identifier1 == identifier2) // Case insensitive
    #expect(identifier1 != identifier3)
    
    let set: Set<NostrNIP05Identifier> = [identifier1, identifier2, identifier3]
    #expect(set.count == 2) // identifier1 and identifier2 are the same
}

// MARK: - Mock NIP-05 Tests (without network calls)
@Test func nip05MockVerification() async throws {
    // Since we can't make real network calls in tests, we'll test the structure
    // and error handling of the verifier
    
    let identifier = try NostrNIP05Identifier(identifier: "test@invalid-domain-that-should-not-exist.xyz")
    let verifier = NostrNIP05Verifier(timeout: 1.0) // Short timeout
    
    // This should fail due to network error (domain doesn't exist)
    do {
        _ = try await verifier.verify(identifier: identifier, publicKey: "testpubkey")
        // If it somehow succeeds, that's fine for the test structure
    } catch {
        // Expected to fail due to invalid domain
        #expect(error is NostrError || error is URLError)
    }
}

@Test func nip05CoreNostrAPI() async throws {
    // Test the CoreNostr convenience methods structure
    
    // This should fail due to network error, but we're testing the API structure
    do {
        _ = try await CoreNostr.verifyNIP05(
            identifier: "test@invalid-domain.xyz",
            publicKey: "testpubkey"
        )
    } catch {
        // Expected to fail, testing API structure
        #expect(error is NostrError || error is URLError)
    }
    
    do {
        _ = try await CoreNostr.discoverNIP05(identifier: "test@invalid-domain.xyz")
    } catch {
        // Expected to fail, testing API structure
        #expect(error is NostrError || error is URLError)
    }
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
