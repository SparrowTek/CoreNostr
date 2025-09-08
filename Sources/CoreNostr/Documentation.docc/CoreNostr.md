# ``CoreNostr``

A comprehensive Swift implementation of the Nostr protocol providing cross-platform primitives for building Nostr applications.

## Overview

CoreNostr is a Swift package that implements the [Nostr (Notes and Other Stuff Transmitted by Relays)](https://github.com/nostr-protocol/nostr) protocol. It provides essential primitives and utilities that can be shared across platforms (iOS, macOS, tvOS, watchOS, Linux) without any networking code.

This library is designed to be:
- **Cross-platform**: Works on all Apple platforms and Linux
- **Comprehensive**: Implements 20+ NIPs (Nostr Implementation Possibilities)
- **Secure**: Uses industry-standard cryptography with safety features
- **Type-safe**: Leverages Swift's type system for safety
- **Well-tested**: Extensive test coverage including property-based and fuzz testing
- **Documented**: Complete DocC documentation with examples

## Features

### Core Protocol
- ✅ Event creation, signing, and verification (NIP-01)
- ✅ Canonical JSON serialization
- ✅ Schnorr signatures using secp256k1
- ✅ Event ID calculation and validation

### Cryptography
- ✅ Key pair generation and management
- ✅ NIP-44 state-of-the-art encryption
- ✅ NIP-17 private direct messages with metadata protection
- ✅ NIP-06 HD key derivation from seed phrases
- ✅ Constant-time comparisons for security
- ✅ Secure random generation

### Encoding & Identifiers
- ✅ NIP-19 Bech32 entities (npub, nsec, note, nprofile, nevent, nrelay, naddr)
- ✅ NIP-21 nostr: URI scheme
- ✅ NIP-05 DNS-based verification
- ✅ Human-readable formats

### Content Types
- ✅ NIP-10 Reply threading and mentions
- ✅ NIP-23 Long-form content (articles)
- ✅ NIP-25 Reactions (likes, emojis)
- ✅ NIP-27 Text note references
- ✅ NIP-51 Lists (mute, pin, bookmark, etc.)
- ✅ NIP-56 Reporting
- ✅ NIP-58 Badges

### Advanced Features
- ✅ NIP-11 Relay information document
- ✅ NIP-13 Proof of Work
- ✅ NIP-40 Expiration timestamps  
- ✅ NIP-42 Authentication
- ✅ NIP-50 Search capabilities
- ✅ NIP-57 Lightning Zaps
- ✅ NIP-59 Gift wrapping
- ✅ NIP-65 Relay list metadata

## Getting Started

### Installation

Add CoreNostr to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CoreNostr.git", from: "1.0.0")
]
```

### Basic Example

```swift
import CoreNostr

// Generate a key pair
let keyPair = try CoreNostr.createKeyPair()
print("Your npub: \(try Bech32Entity.npub(keyPair.publicKey).encoded)")

// Create and sign an event
let event = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, Nostr! 🚀"
)

// Verify the event
let isValid = try CoreNostr.verifyEvent(event)
print("Event valid: \(isValid)")
print("Event ID: \(event.id)")

// Create a filter to query events
let filter = FilterBuilder()
    .authors([keyPair.publicKey])
    .kinds([1]) // Text notes
    .since(Date().addingTimeInterval(-3600))
    .limit(20)
    .build()
```

## Topics

### Essentials
- ``CoreNostr`` - Main entry point with convenience methods
- ``NostrEvent`` - Core event type  
- ``KeyPair`` - Key pair management
- ``Filter`` - Event filtering
- ``EventKind`` - Standard event kinds

### Cryptography & Security
- ``NostrCrypto`` - Cryptographic operations
- ``NIP44`` - Modern encryption standard
- ``NIP06`` - HD key derivation
- ``Security`` - Security utilities

### Event Creation
- ``EventBuilder`` - Fluent API for event creation
- ``FilterBuilder`` - Fluent API for filter creation
- ``Validation`` - Input validation utilities

### Communication
- ``NIP17`` - Private direct messages
- ``NostrDirectMessage`` - Direct message helpers
- ``NIP25`` - Reactions

### Content & Social
- ``NIP23`` - Long-form content
- ``NIP51`` - Lists and collections
- ``NostrFollowList`` - Follow list management
- ``NIP10`` - Reply threading

### Encoding & Discovery
- ``NIP19`` - Bech32 encoding
- ``Bech32Entity`` - Bech32 entity types
- ``NostrNIP05Identifier`` - NIP-05 identifiers
- ``NIP21`` - URI scheme

### Advanced Features
- ``NIP11`` - Relay information
- ``NIP13`` - Proof of Work
- ``NIP42`` - Authentication
- ``NIP57`` - Lightning Zaps
- ``NIP65`` - Relay metadata

### Type Aliases
- ``PublicKey`` - 64-character hex public key
- ``PrivateKey`` - 64-character hex private key
- ``EventID`` - 64-character hex event ID
- ``Signature`` - 128-character hex signature

### Errors
- ``NostrError`` - Unified error type

## Documentation

### Guides
- <doc:QuickStart> - Get started quickly
- <doc:WorkingWithNIPs> - Comprehensive NIP guide
- <doc:SecurityBestPractices> - Security guidelines
- <doc:BuildingNostrApp> - Build a complete app

### Tutorials
- <doc:GettingStarted> - Step-by-step introduction

## Requirements

- Swift 6.0+
- iOS 17.0+ / macOS 15.0+ / tvOS 17.0+ / watchOS 10.0+ / Linux

## Dependencies

CoreNostr uses these trusted libraries:
- [secp256k1](https://github.com/21-DOT-DEV/swift-secp256k1) - Schnorr signatures
- [swift-crypto](https://github.com/apple/swift-crypto) - Cryptographic operations
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) - Additional crypto
- [BigInt](https://github.com/attaswift/BigInt) - Large number operations
- [SwiftCBOR](https://github.com/valpackett/SwiftCBOR) - CBOR encoding
- [Vault](https://github.com/SparrowTek/Vault) - Secure storage

## Contributing

Contributions are welcome! Please:
1. Follow Swift API design guidelines
2. Add tests for new features
3. Update documentation
4. Ensure all tests pass

## License

MIT License - See LICENSE file for details

## Resources

- [Nostr Protocol](https://github.com/nostr-protocol/nostr)
- [NIP Repository](https://github.com/nostr-protocol/nips)
- [Nostr.how](https://nostr.how) - User guide
- [Awesome Nostr](https://github.com/aljazceru/awesome-nostr) - Resources