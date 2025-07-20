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

- ``Crypto``
- ``NIP44``
- ``NIP06``

### Event Types and Creation

- ``NostrDirectMessage``
- ``NostrFollowList``
- ``NostrOpenTimestamps``
- ``NIP09``
- ``NIP13``
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

- ``NostrNIP05``
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

## NIP Support

CoreNostr implements numerous NIPs (Nostr Implementation Possibilities):

- **NIP-01**: Basic protocol flow description
- **NIP-06**: Basic key derivation from mnemonic seed phrase
- **NIP-09**: Event deletion
- **NIP-10**: Reply threading and mentions
- **NIP-11**: Relay information document
- **NIP-13**: Proof of Work
- **NIP-17**: Private Direct Messages
- **NIP-19**: bech32-encoded entities
- **NIP-21**: nostr: URI scheme
- **NIP-23**: Long-form Content
- **NIP-25**: Reactions
- **NIP-27**: Text Note References
- **NIP-40**: Expiration Timestamp
- **NIP-42**: Authentication of clients to relays
- **NIP-44**: Encrypted Payloads (Versioned)
- **NIP-50**: Search Capability
- **NIP-51**: Lists
- **NIP-56**: Reporting
- **NIP-57**: Lightning Zaps
- **NIP-58**: Badges
- **NIP-59**: Gift Wrap
- **NIP-65**: Relay List Metadata

## Important Notes

- This library contains only protocol primitives and does not include networking code
- Networking should be handled by the libraries that import CoreNostr
- All cryptographic operations use industry-standard libraries
- Comprehensive validation is performed on all inputs to ensure protocol compliance