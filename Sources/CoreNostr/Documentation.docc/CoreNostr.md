# ``CoreNostr``

A comprehensive Swift implementation of the Nostr protocol providing cross-platform primitives for building Nostr applications.

## Overview

CoreNostr is a Swift package that implements the Nostr (Notes and Other Stuff Transmitted by Relays) protocol. It provides essential primitives and utilities that can be shared across platforms (iOS, macOS, Linux) without any networking code.

This library focuses on:
- Event creation and validation
- Cryptographic operations (signing, verification, encryption)
- NIP (Nostr Implementation Possibilities) support
- Data encoding/decoding
- Protocol compliance

## Topics

### Essentials

- ``NostrEvent``
- ``KeyPair``
- ``CoreNostr``
- ``Filter``
- ``EventKind``

### Cryptography

- ``NostrCrypto``
- ``NIP44``
- ``NIP06``

### Event Types and Creation

- ``NostrDirectMessage``
- ``NostrFollowList``
- ``NostrOpenTimestamps``
- ``NIP17``
- ``NIP23``
- ``NIP25``
- ``NIP51``

### Content and Metadata

- ``NIP10``
- ``NIP19``
- ``NIP21``
- ``NIP27``
- ``NIP40``
- ``NIP50``
- ``NIP56``
- ``NIP58``
- ``NIP65``

### Networking and Discovery

- ``NostrNIP05Identifier``
- ``NostrNIP05Response``
- ``NostrNIP05Discovery``
- ``NostrNIP05DiscoveryResult``
- ``NIP11``
- ``NIP42``
- ``NIP57``
- ``NIP59``

### Validation and Utilities

- ``Validation``
- ``NostrError``

### Type Aliases

- ``PublicKey``
- ``PrivateKey``
- ``EventID``
- ``Signature``

## Getting Started

To start using CoreNostr, first generate a key pair:

```swift
import CoreNostr

// Generate a new key pair
let keyPair = try CoreNostr.createKeyPair()

// Create a text note
let note = try CoreNostr.createTextNote(
    keyPair: keyPair,
    content: "Hello, Nostr!"
)

// Verify the event
let isValid = try CoreNostr.verifyEvent(note)
```

## Important Notes

- All cryptographic operations use industry-standard libraries
- Comprehensive validation is performed on all inputs to ensure protocol compliance