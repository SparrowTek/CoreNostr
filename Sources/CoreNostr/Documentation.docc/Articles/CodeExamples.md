# Code Examples

Complete, runnable examples for common CoreNostr use cases.

## Overview

This article provides copy-paste ready code examples for the most common Nostr operations using CoreNostr.

## Complete Event Lifecycle

```swift
import CoreNostr
import Foundation

// 1. Generate or restore a key pair
func setupKeys() throws -> KeyPair {
    // Option A: Generate new keys
    let newKeyPair = try CoreNostr.createKeyPair()
    
    // Option B: Restore from private key
    let privateKey = "your_private_key_hex"
    let restoredKeyPair = try KeyPair(privateKey: privateKey)
    
    // Option C: Derive from seed phrase (NIP-06)
    let mnemonic = try NIP06.generateMnemonic()
    let seed = try NIP06.mnemonicToSeed(mnemonic: mnemonic)
    let derivedKeyPair = try NIP06.deriveKeyPair(from: seed, accountIndex: 0)
    
    return newKeyPair
}

// 2. Create various event types
func createEvents(keyPair: KeyPair) throws {
    // Text note
    let textNote = try CoreNostr.createTextNote(
        keyPair: keyPair,
        content: "Hello Nostr!"
    )
    
    // Reply with threading
    let reply = try CoreNostr.createTextNote(
        keyPair: keyPair,
        content: "Great point!",
        tags: [
            ["e", "root_event_id", "wss://relay.example.com", "root"],
            ["e", "reply_to_event_id", "wss://relay.example.com", "reply"],
            ["p", "original_author_pubkey"]
        ]
    )
    
    // Reaction
    let reaction = try NIP25.createReaction(
        content: "⚡",
        eventId: "target_event_id",
        eventPubkey: "target_author_pubkey",
        keyPair: keyPair
    )
    
    // Long-form article
    let article = try NIP23.createArticle(
        title: "Understanding Nostr",
        content: "# Introduction\\n\\nNostr is a decentralized protocol...",
        summary: "An introduction to Nostr",
        tags: ["nostr", "decentralized", "protocol"],
        keyPair: keyPair
    )
}

// 3. Work with filters
func queryEvents() -> [Filter] {
    // Recent text notes from specific authors
    let textNotes = FilterBuilder()
        .authors(["author_pubkey_1", "author_pubkey_2"])
        .kinds([1])
        .since(Date().addingTimeInterval(-3600))
        .limit(50)
        .build()
    
    // User's notifications (mentions)
    let mentions = FilterBuilder()
        .kinds([1])
        .p(["my_pubkey"])
        .since(Date().addingTimeInterval(-86400))
        .build()
    
    // Profile metadata
    let profiles = FilterBuilder()
        .authors(["user_pubkey"])
        .kinds([0])
        .limit(1)
        .build()
    
    return [textNotes, mentions, profiles]
}
```

## Encrypted Communication

```swift
import CoreNostr

class SecureMessaging {
    let myKeyPair: KeyPair
    
    init() throws {
        self.myKeyPair = try CoreNostr.createKeyPair()
    }
    
    // Send encrypted message (NIP-17)
    func sendPrivateMessage(to recipientPubkey: String, message: String) throws -> NostrEvent {
        let encrypted = try NIP17.createDirectMessage(
            content: message,
            senderKeyPair: myKeyPair,
            recipientPubkey: recipientPubkey,
            subject: "Private conversation"
        )
        
        // Gift wrap for metadata protection
        let wrapped = try NIP17.giftWrap(
            event: encrypted,
            senderKeyPair: myKeyPair,
            recipientPubkey: recipientPubkey
        )
        
        return wrapped
    }
    
    // Receive and decrypt message
    func receiveMessage(_ event: NostrEvent) throws -> String? {
        // Check if it's a gift-wrapped message
        guard event.kind == 1059 else { return nil }
        
        // Unwrap and decrypt
        let unwrapped = try NIP17.unwrapGift(
            event: event,
            recipientKeyPair: myKeyPair
        )
        
        return unwrapped.content
    }
    
    // Encrypt arbitrary data (NIP-44)
    func encryptData(_ data: String, for recipientPubkey: String) throws -> String {
        return try NIP44.encrypt(
            plaintext: data,
            senderPrivateKey: myKeyPair.privateKey,
            recipientPublicKey: recipientPubkey
        )
    }
    
    // Decrypt arbitrary data
    func decryptData(_ encrypted: String, from senderPubkey: String) throws -> String {
        return try NIP44.decrypt(
            payload: encrypted,
            recipientPrivateKey: myKeyPair.privateKey,
            senderPublicKey: senderPubkey
        )
    }
}
```

## Social Features

```swift
import CoreNostr

class SocialFeatures {
    let keyPair: KeyPair
    
    init(keyPair: KeyPair) {
        self.keyPair = keyPair
    }
    
    // Follow/unfollow users
    func updateFollowList(follows: Set<String>) throws -> NostrEvent {
        let followEntries = follows.map { pubkey in
            FollowEntry(pubkey: pubkey, relayURL: nil, petname: nil)
        }
        
        return try CoreNostr.createFollowListEvent(
            keyPair: keyPair,
            follows: followEntries
        )
    }
    
    // Create various lists (NIP-51)
    func createLists() throws {
        // Mute list
        let muteList = try NIP51.createList(
            kind: .muteList,
            items: [
                .pubkey("annoying_user_pubkey", nil),
                .hashtag("spam", nil)
            ],
            keyPair: keyPair
        )
        
        // Bookmark list (private)
        let bookmarks = try NIP51.createList(
            kind: .bookmarkList,
            items: [
                .event("interesting_event_id", "wss://relay.example.com")
            ],
            isPrivate: true,
            keyPair: keyPair
        )
        
        // Pin list
        let pins = try NIP51.createList(
            kind: .pinList,
            items: [
                .event("pinned_note_id", nil)
            ],
            keyPair: keyPair
        )
    }
    
    // Report content (NIP-56)
    func reportContent(eventId: String, reason: NIP56.ReportType) throws -> NostrEvent {
        return try NIP56.createReport(
            reportedEventId: eventId,
            reportType: reason,
            content: "Additional context about the report",
            reporterKeyPair: keyPair
        )
    }
    
    // Create a badge (NIP-58)
    func awardBadge(to recipientPubkey: String) throws -> NostrEvent {
        let badge = NIP58.Badge(
            id: "contributor",
            name: "Active Contributor",
            description: "Awarded for valuable contributions",
            image: "https://example.com/badge.png",
            thumbs: ["https://example.com/badge-thumb.png"]
        )
        
        return try NIP58.createBadgeAward(
            badge: badge,
            recipientPubkeys: [recipientPubkey],
            keyPair: keyPair
        )
    }
}
```

## NIP-05 Verification

```swift
import CoreNostr

class NIP05Verification {
    // Verify a Nostr address
    func verifyAddress(_ address: String) async throws -> String? {
        // Parse address (e.g., "alice@example.com")
        let parts = address.split(separator: "@")
        guard parts.count == 2 else { throw NostrError.invalidNIP05 }
        
        let username = String(parts[0])
        let domain = String(parts[1])
        
        let identifier = NostrNIP05Identifier(
            username: username,
            domain: domain
        )
        
        // Fetch .well-known URL
        let url = identifier.wellKnownURL
        
        // In a real app, you'd fetch this URL
        // let (data, _) = try await URLSession.shared.data(from: url)
        // let response = try JSONDecoder().decode(NostrNIP05Response.self, from: data)
        
        // Mock response for example
        let response = NostrNIP05Response(
            names: [username: "user_pubkey_hex"],
            relays: ["user_pubkey_hex": ["wss://relay.example.com"]]
        )
        
        return response.names[username]
    }
    
    // Add NIP-05 to profile
    func updateProfile(nip05: String) throws -> NostrEvent {
        let metadata = UserMetadata(
            name: "Alice",
            about: "Nostr enthusiast",
            picture: "https://example.com/avatar.jpg",
            nip05: nip05
        )
        
        return try CoreNostr.createMetadataEvent(
            keyPair: try CoreNostr.createKeyPair(),
            metadata: metadata
        )
    }
}
```

## Relay Management

```swift
import CoreNostr

class RelayManagement {
    // Specify relay preferences (NIP-65)
    func setRelayList(keyPair: KeyPair) throws -> NostrEvent {
        let relays = [
            NIP65.RelayEntry(
                url: "wss://relay.damus.io",
                read: true,
                write: true
            ),
            NIP65.RelayEntry(
                url: "wss://nostr.wine",
                read: true,
                write: false
            ),
            NIP65.RelayEntry(
                url: "wss://relay.snort.social",
                read: false,
                write: true
            )
        ]
        
        return try NIP65.createRelayList(
            relays: relays,
            keyPair: keyPair
        )
    }
    
    // Handle authentication (NIP-42)
    func authenticate(challenge: String, keyPair: KeyPair) throws -> NostrEvent {
        return try NIP42.createAuthResponse(
            relayUrl: "wss://relay.example.com",
            challenge: challenge,
            keyPair: keyPair
        )
    }
    
    // Check relay capabilities (NIP-11)
    func parseRelayInfo(jsonData: Data) throws -> NIP11.RelayInformation {
        let info = try JSONDecoder().decode(NIP11.RelayInformation.self, from: jsonData)
        
        // Check supported features
        let supportsSearch = info.supportedNips?.contains(50) ?? false
        let supportsNIP44 = info.supportedNips?.contains(44) ?? false
        
        print("Relay: \\(info.name)")
        print("Supports search: \\(supportsSearch)")
        print("Supports NIP-44: \\(supportsNIP44)")
        
        return info
    }
}
```

## Advanced Features

```swift
import CoreNostr

class AdvancedFeatures {
    // Add proof of work (NIP-13)
    func addProofOfWork(to event: NostrEvent, difficulty: Int) throws -> NostrEvent {
        let mined = try NIP13.mine(
            event: event,
            targetDifficulty: difficulty,
            timeout: 30.0
        )
        
        // Verify the work
        let actualDifficulty = NIP13.calculateDifficulty(for: mined.id)
        print("Mined with \\(actualDifficulty) bits of work")
        
        return mined
    }
    
    // Create expiring events (NIP-40)
    func createExpiringNote(keyPair: KeyPair) throws -> NostrEvent {
        let expiresAt = Date().addingTimeInterval(3600) // 1 hour
        
        return try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: "This message will self-destruct",
            tags: [
                ["expiration", String(Int(expiresAt.timeIntervalSince1970))]
            ]
        )
    }
    
    // Lightning zaps (NIP-57)
    func createZapRequest(
        amount: Int,
        eventId: String,
        recipientPubkey: String,
        keyPair: KeyPair
    ) throws -> NostrEvent {
        return try NIP57.createZapRequest(
            amount: amount,
            eventId: eventId,
            recipientPubkey: recipientPubkey,
            comment: "Great content! ⚡",
            keyPair: keyPair
        )
    }
    
    // Text note references (NIP-27)
    func createNoteWithReferences(keyPair: KeyPair) throws -> NostrEvent {
        let content = """
        Check out this note: nostr:note1xyz...
        And this profile: nostr:npub1abc...
        """
        
        return try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: content,
            tags: [
                ["e", "referenced_event_id"],
                ["p", "referenced_pubkey"]
            ]
        )
    }
}
```

## Error Handling

```swift
import CoreNostr

func robustEventHandling() {
    do {
        let keyPair = try CoreNostr.createKeyPair()
        
        let event = try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: "Test"
        )
        
        // Validate before sending
        try Validation.validateEvent(event)
        
        // Verify signature
        guard try CoreNostr.verifyEvent(event) else {
            throw NostrError.invalidSignature
        }
        
        print("Event ready to broadcast: \\(event.id)")
        
    } catch NostrError.invalidPublicKey {
        print("Invalid public key format")
    } catch NostrError.invalidPrivateKey {
        print("Invalid private key format")
    } catch NostrError.signingFailed {
        print("Failed to sign event")
    } catch NostrError.invalidSignature {
        print("Invalid event signature")
    } catch {
        print("Unexpected error: \\(error)")
    }
}
```

## Testing Helpers

```swift
import CoreNostr
import Testing

@Suite("Nostr Event Tests")
struct EventTests {
    @Test("Create and verify event")
    func testEventCreation() throws {
        let keyPair = try CoreNostr.createKeyPair()
        
        let event = try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: "Test note"
        )
        
        #expect(event.kind == 1)
        #expect(event.pubkey == keyPair.publicKey)
        #expect(try CoreNostr.verifyEvent(event))
    }
    
    @Test("Bech32 round-trip")
    func testBech32Encoding() throws {
        let pubkey = String(repeating: "0", count: 64)
        
        let npub = try Bech32Entity.npub(pubkey).encoded
        #expect(npub.starts(with: "npub1"))
        
        let decoded = try Bech32Entity(from: npub)
        if case .npub(let decodedPubkey) = decoded {
            #expect(decodedPubkey == pubkey)
        } else {
            Issue.record("Failed to decode npub")
        }
    }
}
```

## See Also

- <doc:QuickStart>
- <doc:WorkingWithNIPs>
- <doc:SecurityBestPractices>