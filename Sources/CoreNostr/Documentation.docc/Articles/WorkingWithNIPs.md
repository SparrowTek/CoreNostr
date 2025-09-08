# Working with NIPs

A comprehensive guide to Nostr Implementation Possibilities (NIPs) supported by CoreNostr.

## Overview

NIPs define standards for the Nostr protocol. CoreNostr implements many NIPs to provide a complete toolkit for building Nostr applications.

## Core NIPs

### NIP-01: Basic Protocol

The foundation of Nostr - defines events, signatures, and basic message flow:

```swift
// Create a basic event
let event = NostrEvent(
    pubkey: keyPair.publicKey,
    createdAt: Date(),
    kind: 1,
    tags: [],
    content: "Hello Nostr"
)

// Sign the event
let signed = try event.sign(with: keyPair)

// Verify signature
let isValid = try signed.verify()
```

### NIP-19: Bech32-Encoded Entities

Human-readable encodings for Nostr entities:

```swift
// Public key encoding
let npub = try Bech32Entity.npub(publicKey).encoded

// Private key encoding (handle with care!)
let nsec = try Bech32Entity.nsec(privateKey).encoded

// Note (event) encoding
let note = try Bech32Entity.note(eventId).encoded

// Profile with relay hints
let profile = NProfile(
    pubkey: publicKey,
    relays: ["wss://relay.damus.io", "wss://nostr.wine"]
)
let nprofile = try Bech32Entity.nprofile(profile).encoded

// Event with metadata
let eventRef = NEvent(
    eventId: eventId,
    relays: ["wss://relay.example.com"],
    author: authorPubkey,
    kind: 1
)
let nevent = try Bech32Entity.nevent(eventRef).encoded
```

## Communication NIPs

### NIP-04: Encrypted Direct Messages (Deprecated)

⚠️ Deprecated in favor of NIP-17. Use only for backward compatibility:

```swift
// Legacy encrypted message
let encrypted = try NostrCrypto.encrypt(
    message: "Secret message",
    senderPrivateKey: sender.privateKey,
    recipientPublicKey: recipient.publicKey
)
```

### NIP-17: Private Direct Messages

Modern encrypted messaging with better metadata protection:

```swift
// Create a private message
let privateMessage = try NIP17.createDirectMessage(
    content: "Private message with metadata protection",
    senderKeyPair: senderKeyPair,
    recipientPubkey: recipientPubkey,
    subject: "Optional subject line"
)

// Handle gift-wrapped events
let giftWrapped = try NIP17.giftWrap(
    event: privateMessage,
    senderKeyPair: senderKeyPair,
    recipientPubkey: recipientPubkey
)
```

### NIP-44: Encrypted Payloads

State-of-the-art encryption for any content:

```swift
// Encrypt arbitrary data
let encrypted = try NIP44.encrypt(
    plaintext: "Sensitive data",
    senderPrivateKey: sender.privateKey,
    recipientPublicKey: recipient.publicKey
)

// Decrypt
let decrypted = try NIP44.decrypt(
    payload: encrypted,
    recipientPrivateKey: recipient.privateKey,
    senderPublicKey: sender.publicKey
)
```

## Content NIPs

### NIP-10: Reply Threading

Proper event threading and mentions:

```swift
// Create a reply with proper threading
let reply = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "This is a reply",
    tags: NIP10.createReplyTags(
        rootEvent: rootEventId,
        replyTo: parentEventId,
        mentions: [mentionedEventId]
    )
)

// Parse thread information
let threadInfo = NIP10.parseThreadTags(from: event.tags)
print("Root: \(threadInfo.root)")
print("Reply to: \(threadInfo.replyTo)")
```

### NIP-23: Long-form Content

Articles and blog posts:

```swift
let article = try NIP23.createArticle(
    title: "Introduction to Nostr",
    content: "# Introduction\n\nNostr is a decentralized protocol...",
    summary: "A beginner's guide to Nostr",
    image: "https://example.com/image.jpg",
    publishedAt: Date(),
    tags: ["nostr", "tutorial", "decentralized"],
    keyPair: keyPair
)
```

### NIP-25: Reactions

Likes, emojis, and other reactions:

```swift
// Create a like
let like = try NIP25.createReaction(
    content: "+",
    eventId: targetEventId,
    eventPubkey: targetEventPubkey,
    keyPair: keyPair
)

// Create an emoji reaction
let emojiReaction = try NIP25.createReaction(
    content: "🚀",
    eventId: targetEventId,
    eventPubkey: targetEventPubkey,
    keyPair: keyPair
)
```

## Social NIPs

### NIP-51: Lists

Mute lists, pin lists, and other categorized lists:

```swift
// Create a mute list
let muteList = try NIP51.createList(
    kind: .muteList,
    items: [
        .pubkey("pubkey_to_mute", nil),
        .event("event_to_mute", nil)
    ],
    keyPair: keyPair
)

// Create a bookmark list
let bookmarks = try NIP51.createList(
    kind: .bookmarkList,
    items: [
        .event(eventId, "wss://relay.example.com")
    ],
    isPrivate: true,
    keyPair: keyPair
)
```

## Discovery NIPs

### NIP-05: DNS-Based Verification

Verify Nostr addresses:

```swift
let identifier = NostrNIP05Identifier(
    username: "alice",
    domain: "nostr.example.com"
)

// Generate the well-known URL
let url = identifier.wellKnownURL
// https://nostr.example.com/.well-known/nostr.json?name=alice

// Parse response
let response = NostrNIP05Response(
    names: ["alice": alicePubkey],
    relays: [alicePubkey: ["wss://relay.example.com"]]
)
```

### NIP-11: Relay Information

Query relay capabilities:

```swift
let relayInfo = NIP11.RelayInformation(
    name: "Example Relay",
    description: "A Nostr relay",
    pubkey: relayPubkey,
    contact: "admin@example.com",
    supportedNips: [1, 2, 9, 11, 12, 15, 16, 20, 22],
    software: "https://github.com/example/relay",
    version: "1.0.0"
)

// Check if relay supports a NIP
let supportsNIP44 = relayInfo.supportedNips?.contains(44) ?? false
```

## Financial NIPs

### NIP-57: Lightning Zaps

Lightning payments for content:

```swift
// Create a zap request
let zapRequest = try NIP57.createZapRequest(
    amount: 1000, // millisats
    eventId: eventToZap,
    recipientPubkey: recipientPubkey,
    comment: "Great post!",
    keyPair: keyPair
)

// Parse zap receipt
let zapReceipt = try NIP57.parseZapReceipt(event: receiptEvent)
print("Amount: \(zapReceipt.amount) sats")
print("From: \(zapReceipt.sender)")
```

## Advanced NIPs

### NIP-13: Proof of Work

Add proof of work to events:

```swift
// Mine an event with difficulty
let minedEvent = try NIP13.mine(
    event: event,
    targetDifficulty: 20
)

// Verify proof of work
let difficulty = NIP13.calculateDifficulty(for: minedEvent.id)
print("Event has \(difficulty) bits of work")
```

### NIP-42: Authentication

Relay authentication challenges:

```swift
// Handle AUTH challenge
let authEvent = try NIP42.createAuthResponse(
    relayUrl: "wss://relay.example.com",
    challenge: challengeString,
    keyPair: keyPair
)
```

### NIP-65: Relay List Metadata

Specify preferred relays:

```swift
let relayList = try NIP65.createRelayList(
    relays: [
        NIP65.RelayEntry(url: "wss://relay1.com", read: true, write: true),
        NIP65.RelayEntry(url: "wss://relay2.com", read: true, write: false),
        NIP65.RelayEntry(url: "wss://relay3.com", read: false, write: true)
    ],
    keyPair: keyPair
)
```

## Best Practices

1. **Always check NIP support**: Verify relay capabilities before using advanced features
2. **Prefer newer NIPs**: Use NIP-17/44 over NIP-04 for encryption
3. **Validate everything**: Check event kinds and tag structures match NIP specs
4. **Handle unknown NIPs gracefully**: Don't crash on unrecognized event kinds
5. **Stay updated**: NIPs evolve - check for updates regularly

## See Also

- <doc:QuickStart>
- <doc:SecurityBestPractices>
- [Official NIP Repository](https://github.com/nostr-protocol/nips)