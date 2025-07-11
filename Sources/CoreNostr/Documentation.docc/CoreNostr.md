# ``CoreNostr``

A Swift package implementing the NOSTR protocol for cross-platform compatibility.

## Overview

CoreNostr is a Swift package that provides a complete implementation of the NOSTR (Notes and Other Stuff Transmitted by Relays) protocol. It offers cross-platform compatibility across iOS, macOS, watchOS, tvOS, and Linux, making it perfect for building decentralized social applications.

The library focuses on providing shared functionality that can be used across different NOSTR implementations, serving as a foundation for more specialized packages like iOS-specific NostrKit and swift-nostr-relay.

## Features

- **Complete NIP-01 Implementation**: Full support for the basic NOSTR protocol specification
- **Modern Swift Concurrency**: Built with async/await and structured concurrency
- **Cross-Platform Support**: Works on all Apple platforms plus Linux
- **Cryptographic Security**: Uses secp256k1 elliptic curve cryptography with Schnorr signatures
- **WebSocket Networking**: Real-time communication with NOSTR relays
- **Type Safety**: Strong typing throughout with comprehensive error handling

## Key Components

### Event Management
- ``NostrEvent`` - Core event structure following NIP-01 specification
- ``EventKind`` - Enumeration of supported event types
- Event creation, signing, and verification

### Cryptography
- ``KeyPair`` - Secure key generation and management
- Digital signatures using Schnorr signatures over secp256k1
- Event ID calculation and validation

### Network Communication
- ``RelayConnection`` - Individual relay connection management
- ``RelayPool`` - Multiple relay connection pooling
- WebSocket-based real-time messaging

### Filtering and Utilities
- ``Filter`` - Event filtering for subscriptions
- ``ClientMessage`` and ``RelayMessage`` - Protocol message types
- Comprehensive validation utilities

## Getting Started

### Installation

Add CoreNostr to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CoreNostr", from: "1.0.0")
]
```

### Basic Usage

```swift
import CoreNostr

// Generate a new key pair
let keyPair = try CoreNostr.createKeyPair()

// Create and sign a text note
let textNote = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, NOSTR world!"
)

// Connect to a relay
let relay = RelayConnection()
try await relay.connect(to: URL(string: "wss://relay.example.com")!)

// Publish the event
try await relay.send(.event(textNote))

// Subscribe to events
let filter = Filter.textNotes(limit: 10)
try await relay.send(.req(subscriptionId: "feed", filters: [filter]))

// Listen for messages
for await message in relay.messages {
    switch message {
    case .event(let subId, let event):
        print("Received: \(event.content)")
    case .eose(let subId):
        print("End of stored events for \(subId)")
    default:
        break
    }
}
```

## Topics

### Essentials
- ``CoreNostr``
- ``NostrEvent``
- ``KeyPair``
- ``RelayConnection``

### Event Management
- ``NostrEvent``
- ``EventKind``
- ``EventID``
- ``Filter``

### Cryptography
- ``KeyPair``
- ``PublicKey``
- ``PrivateKey``
- ``Signature``
- ``NostrCrypto``

### Network Communication
- ``RelayConnection``
- ``RelayPool``
- ``ClientMessage``
- ``RelayMessage``
- ``ConnectionState``

### Error Handling
- ``NostrError``

## See Also

- [NOSTR Protocol Specification](https://github.com/nostr-protocol/nips)
- [NIP-01: Basic Protocol](https://github.com/nostr-protocol/nips/blob/master/01.md)