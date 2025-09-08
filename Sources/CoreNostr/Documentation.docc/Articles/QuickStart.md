# Quick Start Guide

A comprehensive guide to get started with CoreNostr quickly.

## Overview

This guide walks you through the essential steps to integrate CoreNostr into your Swift application and start working with the Nostr protocol.

## Installation

Add CoreNostr to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CoreNostr.git", from: "1.0.0")
]
```

## Basic Usage

### Creating a Key Pair

Every Nostr user needs a key pair for signing events:

```swift
import CoreNostr

// Generate a new key pair
let keyPair = try CoreNostr.createKeyPair()

// Access the public key (use this as your Nostr identity)
let publicKey = keyPair.publicKey

// Access the private key (keep this secret!)
let privateKey = keyPair.privateKey
```

### Creating Events

#### Text Note (Kind 1)

```swift
let textNote = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, Nostr! 🚀"
)

// The event is now signed and ready to broadcast
print("Event ID: \(textNote.id)")
```

#### Reply to Another Event

```swift
let reply = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Great post!",
    tags: [
        ["e", originalEventId, "wss://relay.example.com", "reply"],
        ["p", originalAuthorPubkey]
    ]
)
```

### Working with Filters

Filters are used to request specific events from relays:

```swift
// Create a filter for text notes from specific authors
let filter = Filter(
    authors: [authorPubkey1, authorPubkey2],
    kinds: [1], // Text notes
    since: Date().addingTimeInterval(-3600), // Last hour
    limit: 20
)

// Using the builder pattern
let filter = FilterBuilder()
    .authors([authorPubkey])
    .kinds([1, 6]) // Text notes and reposts
    .since(Date().addingTimeInterval(-86400))
    .limit(100)
    .build()
```

### Bech32 Encoding (NIP-19)

Convert between hex and human-readable formats:

```swift
// Encode a public key as npub
let npub = try Bech32Entity.npub(publicKey).encoded
print("Share your npub: \(npub)")

// Decode an npub back to hex
let decoded = try Bech32Entity(from: "npub1...")
if case .npub(let hexPubkey) = decoded {
    print("Public key: \(hexPubkey)")
}

// Encode an event ID as note
let noteId = try Bech32Entity.note(eventId).encoded
```

### Encrypted Direct Messages (NIP-17)

Send private messages between users:

```swift
// Create an encrypted direct message
let encryptedMessage = try NIP17.createDirectMessage(
    content: "This is a private message",
    senderKeyPair: senderKeyPair,
    recipientPubkey: recipientPubkey
)

// Decrypt a received message
let decrypted = try NIP17.decryptDirectMessage(
    event: receivedEvent,
    recipientKeyPair: myKeyPair
)
print("Message: \(decrypted)")
```

### NIP-05 Verification

Verify Nostr addresses (like alice@example.com):

```swift
// Create a NIP-05 identifier
let identifier = NostrNIP05Identifier(
    username: "alice",
    domain: "example.com"
)

// The relay would fetch from:
// https://example.com/.well-known/nostr.json?name=alice
```

### Event Validation

Always validate events before processing:

```swift
// Verify an event's signature
let isValid = try CoreNostr.verifyEvent(event)

// Validate specific aspects
try Validation.validatePublicKey(pubkey)
try Validation.validateEventId(eventId)
try Validation.validateTimestamp(timestamp)
```

## Best Practices

1. **Key Management**: Never expose private keys in logs or UI
2. **Validation**: Always validate incoming events before processing
3. **Error Handling**: Use proper error handling for all operations
4. **Performance**: Cache validated events to avoid re-validation
5. **Security**: Use NIP-44 for new encrypted communications (not NIP-04)

## Next Steps

- Explore ``NostrEvent`` for advanced event creation
- Learn about ``Filter`` for complex queries
- Read about specific NIPs in their respective documentation
- Check out ``EventBuilder`` for fluent event creation

## See Also

- <doc:WorkingWithNIPs>
- <doc:SecurityBestPractices>
- <doc:BuildingNostrApp>