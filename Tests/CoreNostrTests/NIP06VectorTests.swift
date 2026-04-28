import Testing
@testable import CoreNostr
import Foundation

/// Official NIP-06 vectors from
/// <https://github.com/nostr-protocol/nips/blob/master/06.md> (also mirrored
/// at `claude/nips/06.md`). The derivation path is `m/44'/1237'/0'/0/0` —
/// the trailing `change` and `address_index` levels are *not* hardened,
/// which the previous implementation got wrong.
@Suite("NIP-06 Test Vectors")
struct NIP06VectorTests {

    @Test("Vector 1: 12-word mnemonic")
    func vector1() throws {
        let mnemonic = "leader monkey parrot ring guide accident before fence cannon height naive bean"

        let keyPair = try NIP06.deriveKeyPair(from: mnemonic)

        #expect(keyPair.privateKey == "7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a")
        #expect(keyPair.publicKey == "17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917")
    }

    @Test("Vector 2: 24-word mnemonic")
    func vector2() throws {
        let mnemonic = "what bleak badge arrange retreat wolf trade produce cricket blur garlic valid proud rude strong choose busy staff weather area salt hollow arm fade"

        let keyPair = try NIP06.deriveKeyPair(from: mnemonic)

        #expect(keyPair.privateKey == "c15d739894c81a2fcfd3a2df85a0d2c0dbc47a280d092799f144d73d7ae78add")
        #expect(keyPair.publicKey == "d41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573")
    }

    @Test("Account index varies the derived key")
    func accountIndexVaries() throws {
        let mnemonic = "leader monkey parrot ring guide accident before fence cannon height naive bean"

        let acct0 = try NIP06.deriveKeyPair(from: mnemonic, account: 0)
        let acct1 = try NIP06.deriveKeyPair(from: mnemonic, account: 1)

        // Same mnemonic but different `account` must yield distinct keys.
        #expect(acct0.privateKey != acct1.privateKey)
        #expect(acct0.publicKey != acct1.publicKey)
        // Account 0 must still match vector 1 — the `account` parameter
        // changes only the third path level.
        #expect(acct0.privateKey == "7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a")
    }
}
