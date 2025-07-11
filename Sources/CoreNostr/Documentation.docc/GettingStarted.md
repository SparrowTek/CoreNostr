# Getting Started with CoreNostr

Learn how to integrate CoreNostr into your project and start building NOSTR applications.

## Overview

This guide will walk you through the basics of using CoreNostr to create, sign, and publish NOSTR events, as well as connect to relays and subscribe to event feeds.

## Installation

### Swift Package Manager

Add CoreNostr to your project using Swift Package Manager by adding it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CoreNostr", from: "1.0.0")
]
```

Or add it through Xcode by going to File → Add Package Dependencies and entering the repository URL.

## Basic Concepts

### Events

In NOSTR, everything is an event. Events are JSON objects that contain:
- A unique ID (calculated from the event contents)
- The author's public key
- A timestamp
- A kind (type) of event
- Optional tags for metadata
- The content
- A digital signature

### Keys

NOSTR uses public-key cryptography. Each user has:
- A private key (kept secret)
- A public key (shared publicly as their identity)

### Relays

Relays are servers that store and forward events. Users can connect to multiple relays to publish and receive events.

## Creating Your First Event

### Step 1: Generate a Key Pair

```swift
import CoreNostr

// Generate a new key pair
let keyPair = try CoreNostr.createKeyPair()

// Or create from an existing private key
let existingKeyPair = try KeyPair(privateKey: "your-private-key-hex")
```

### Step 2: Create and Sign an Event

```swift
// Create a simple text note
let textNote = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, NOSTR world!"
)

// Create a metadata event (profile information)
let metadata = try CoreNostr.createMetadataEvent(
    keyPair: keyPair,
    name: "Alice",
    about: "NOSTR enthusiast",
    picture: "https://example.com/alice.jpg"
)
```

### Step 3: Verify Events

```swift
// Verify an event's signature
let isValid = try CoreNostr.verifyEvent(textNote)
print("Event is valid: \(isValid)")
```

## Connecting to Relays

### Single Relay Connection

```swift
// Create a relay connection
let relay = RelayConnection()

// Connect to a relay
try await relay.connect(to: URL(string: "wss://relay.example.com")!)

// Check connection state
print("Connected: \(relay.state)")
```

### Multiple Relays with RelayPool

```swift
// Create a relay pool for managing multiple connections
let pool = RelayPool()

// Add multiple relays
try await pool.addRelay(URL(string: "wss://relay1.example.com")!)
try await pool.addRelay(URL(string: "wss://relay2.example.com")!)

// Broadcast to all relays
await pool.publishEvent(textNote)
```

## Publishing Events

```swift
// Publish an event to a single relay
try await relay.send(.event(textNote))

// Or broadcast to all relays in a pool
await pool.publishEvent(textNote)
```

## Subscribing to Events

### Creating Filters

```swift
// Filter for text notes from specific authors
let filter = Filter.textNotes(
    authors: [keyPair.publicKey],
    limit: 20
)

// Filter for replies to a specific event
let repliesFilter = Filter.replies(
    to: "event-id-here",
    limit: 10
)

// Custom filter
let customFilter = Filter(
    kinds: [1], // Text notes
    since: Date().addingTimeInterval(-3600), // Last hour
    limit: 50
)
```

### Subscribing and Listening

```swift
// Subscribe to events
try await relay.send(.req(
    subscriptionId: "my-feed",
    filters: [filter]
))

// Listen for messages
for await message in relay.messages {
    switch message {
    case .event(let subscriptionId, let event):
        print("New event in \(subscriptionId): \(event.content)")
        
    case .eose(let subscriptionId):
        print("End of stored events for \(subscriptionId)")
        
    case .ok(let eventId, let accepted, let message):
        print("Event \(eventId) \(accepted ? "accepted" : "rejected"): \(message ?? "")")
        
    case .notice(let notice):
        print("Relay notice: \(notice)")
        
    default:
        break
    }
}
```

### Closing Subscriptions

```swift
// Close a specific subscription
try await relay.send(.close(subscriptionId: "my-feed"))

// Or close all subscriptions to a relay
await relay.disconnect()
```

## Error Handling

CoreNostr provides comprehensive error handling through the ``NostrError`` enum:

```swift
do {
    let keyPair = try CoreNostr.createKeyPair()
    let event = try CoreNostr.createTextNote(keyPair: keyPair, content: "Hello!")
    try await relay.send(.event(event))
} catch let error as NostrError {
    switch error {
    case .cryptographyError(let message):
        print("Crypto error: \(message)")
    case .networkError(let message):
        print("Network error: \(message)")
    case .invalidEvent(let message):
        print("Invalid event: \(message)")
    case .serializationError(let message):
        print("Serialization error: \(message)")
    }
} catch {
    print("Unknown error: \(error)")
}
```

## Complete Example

Here's a complete example that demonstrates creating a key pair, connecting to a relay, publishing an event, and subscribing to a feed:

```swift
import CoreNostr

@MainActor
class NostrClient: ObservableObject {
    let keyPair: KeyPair
    let relay = RelayConnection()
    
    init() throws {
        self.keyPair = try CoreNostr.createKeyPair()
    }
    
    func start() async throws {
        // Connect to relay
        try await relay.connect(to: URL(string: "wss://relay.example.com")!)
        
        // Publish a hello message
        let helloEvent = try CoreNostr.createTextNote(
            keyPair: keyPair,
            content: "Hello from CoreNostr!"
        )
        try await relay.send(.event(helloEvent))
        
        // Subscribe to recent text notes
        let filter = Filter.textNotes(limit: 10)
        try await relay.send(.req(subscriptionId: "feed", filters: [filter]))
        
        // Listen for events
        Task {
            for await message in relay.messages {
                switch message {
                case .event(_, let event):
                    print("📝 \(event.content)")
                case .eose(let subId):
                    print("✅ End of stored events for \(subId)")
                default:
                    break
                }
            }
        }
    }
}
```

## Next Steps

- Explore the full API documentation
- Learn about advanced filtering techniques
- Implement custom event types
- Build relay pool management
- Add authentication and authorization

## See Also

- ``CoreNostr``
- ``NostrEvent``
- ``KeyPair``
- ``RelayConnection``
- ``Filter``