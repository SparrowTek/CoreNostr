# Getting Started with CoreNostr

Learn how to use CoreNostr to build Nostr applications.

## Overview

This tutorial will guide you through the basics of using CoreNostr, from creating your first key pair to publishing and verifying events.

### Prerequisites

- Swift 6.0 or later
- Xcode 15.0 or later (for iOS/macOS development)
- Basic understanding of Swift

### Installation

Add CoreNostr to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CoreNostr.git", from: "1.0.0")
]
```

## Creating a Key Pair

The first step in using Nostr is generating a key pair:

```swift
import CoreNostr

// Generate a new random key pair
let keyPair = try CoreNostr.createKeyPair()

print("Public key: \(keyPair.publicKey)")
// Never log private keys in production!
print("Private key: \(keyPair.privateKey)")

// Or create from an existing private key
let existingKeyPair = try KeyPair(privateKey: "your-64-character-hex-private-key")
```

## Creating Events

### Text Notes

The most common type of event is a text note (kind 1):

```swift
// Simple text note
let note = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, Nostr world! 🎉"
)

// Text note with mentions and replies
let replyNote = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Great post! I agree.",
    replyTo: "event-id-to-reply-to",
    mentionedUsers: ["user-pubkey-to-mention"]
)
```

### Metadata Events

Set your profile information with metadata events (kind 0):

```swift
let metadata = try CoreNostr.createMetadataEvent(
    keyPair: keyPair,
    name: "Alice",
    about: "Nostr enthusiast and developer",
    picture: "https://example.com/avatar.jpg",
    nip05: "alice@example.com",
    lud16: "alice@walletofsatoshi.com"
)
```

## Working with Filters

Filters allow you to request specific events from relays:

```swift
// Filter for text notes from specific authors
let filter = Filter(
    authors: ["author-pubkey-1", "author-pubkey-2"],
    kinds: [EventKind.textNote.rawValue],
    since: Date().addingTimeInterval(-3600), // Last hour
    limit: 50
)

// Filter for replies to a specific event
let replyFilter = Filter(
    kinds: [EventKind.textNote.rawValue],
    e: ["parent-event-id"],
    limit: 20
)

// Search filter (requires NIP-50 support)
let searchFilter = Filter(
    search: "bitcoin conference",
    kinds: [EventKind.textNote.rawValue],
    limit: 100
)
```

## Verifying Events

Always verify events received from relays:

```swift
do {
    let isValid = try CoreNostr.verifyEvent(event)
    if isValid {
        print("Event signature is valid")
    } else {
        print("Event signature is invalid")
    }
} catch {
    print("Error verifying event: \(error)")
}
```

## Direct Messages

Send encrypted direct messages (NIP-17):

```swift
// Create an encrypted direct message
let dm = try NIP17.createDirectMessage(
    content: "This is a private message",
    recipientPubkey: "recipient-public-key",
    senderKeyPair: keyPair
)

// The message will be wrapped in a gift wrap event for privacy
let giftWrappedMessage = dm
```

## Working with NIPs

CoreNostr implements many NIPs. Here are some examples:

### NIP-19: Bech32 Encoding

```swift
// Encode a public key as npub
let npub = try keyPair.publicKey.npub

// Decode a bech32 entity
let entity = try Bech32Entity(from: "npub1...")
if case .npub(let pubkey) = entity {
    print("Decoded public key: \(pubkey)")
}
```

### NIP-25: Reactions

```swift
// Create a like reaction
let like = try NIP25.createReaction(
    to: targetEvent,
    content: "👍",
    keyPair: keyPair
)

// Create a custom emoji reaction
let customReaction = try NIP25.createReaction(
    to: targetEvent,
    content: ":custom_emoji:",
    keyPair: keyPair
)
```

### NIP-40: Expiring Events

```swift
// Create an event that expires in 24 hours
let expiringEvent = NostrEvent(
    pubkey: keyPair.publicKey,
    kind: EventKind.textNote.rawValue,
    tags: [NIP40.expirationTag(after: .hours(24))],
    content: "This message will self-destruct in 24 hours"
)
let signedExpiringEvent = try keyPair.signEvent(expiringEvent)
```

## Error Handling

CoreNostr uses comprehensive validation and provides detailed error messages:

```swift
do {
    // This will throw if the public key is invalid
    let event = try NostrEvent(
        id: "invalid-id", // Too short
        pubkey: keyPair.publicKey,
        createdAt: Int64(Date().timeIntervalSince1970),
        kind: 1,
        tags: [],
        content: "Test",
        sig: "invalid-sig"
    )
} catch NostrError.invalidEvent(let message) {
    print("Invalid event: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Always validate inputs**: Use the Validation utilities for user-provided data
2. **Handle errors gracefully**: All operations that can fail are marked with `throws`
3. **Never expose private keys**: Store them securely using Keychain or similar
4. **Verify events**: Always verify signatures on events from untrusted sources
5. **Use appropriate NIPs**: Choose the right NIP for your use case

## Next Steps

- Explore the various NIPs implemented in CoreNostr
- Learn about advanced features like NIP-44 encryption
- Integrate with a relay library for networking
- Build your first Nostr client!