# ``CoreNostr``

## Topics

### Creating Events

- ``createKeyPair()``
- ``createTextNote(keyPair:content:tags:)``
- ``createMetadataEvent(keyPair:metadata:)``
- ``createFollowListEvent(keyPair:follows:)``
- ``createDirectMessageEvent(senderKeyPair:recipientPublicKey:message:replyToEventId:)``
- ``createOpenTimestampsEvent(keyPair:eventId:relayURL:otsData:)``

### Verifying Events

- ``verifyEvent(_:)``
- ``verifySignature(of:)``

### Decrypting Messages

- ``decryptDirectMessage(event:recipientKeyPair:)``

### Working with Keys

- ``generatePrivateKey()``
- ``derivePublicKey(from:)``

### Validation

- ``validatePublicKey(_:)``
- ``validatePrivateKey(_:)``
- ``validateEventId(_:)``