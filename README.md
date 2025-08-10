# CoreNostr

Core Nostr components and logic for Swift Nostr frameworks.

## Usage

Create and sign a text note (NIP-01):

```swift
let keyPair = try CoreNostr.createKeyPair()
let note = try CoreNostr.createTextNote(keyPair: keyPair, content: "Hello, Nostr!")
```

Create and decrypt a private direct message (NIP-44):

```swift
let sender = try CoreNostr.createKeyPair()
let recipient = try CoreNostr.createKeyPair()

let dm = try CoreNostr.createDirectMessageEventNIP44(
  senderKeyPair: sender,
  recipientPublicKey: recipient.publicKey,
  message: "secret"
)

let plaintext = try CoreNostr.decryptDirectMessageNIP44(event: dm, recipientKeyPair: recipient)
```

Connect to a relay and listen for messages:

```swift
let relay = RelayConnection()
try await relay.connect(to: URL(string: "wss://relay.example.com")!)
for await message in relay.messages {
  print(message)
}
```

Note: NIP-04 APIs are deprecated and provided only for backward compatibility. Prefer NIP-17/NIP-44 in new code.
