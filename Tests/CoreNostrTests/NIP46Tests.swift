import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-46: Remote Signing URIs and messages")
struct NIP46Tests {

    private let clientPubkey = "83f3b2ae6aa368e8275397b9c26cf550101d63ebaab900d19dd4a4429f5ad8f5"
    private let signerPubkey = "fa984bd7dbb282f07e16e7ae87b26a2a7b9b90b7246a44771f0cf5ae58018f52"

    // MARK: - nostrconnect://

    @Test("Parses the spec's nostrconnect example, including its form-encoded name")
    func parseSpecExample() throws {
        let uri = "nostrconnect://\(clientPubkey)?relay=wss%3A%2F%2Frelay1.example.com&perms=nip44_encrypt%2Cnip44_decrypt%2Csign_event%3A13%2Csign_event%3A14%2Csign_event%3A1059&name=My+Client&secret=0s8j2djs&relay=wss%3A%2F%2Frelay2.example2.com"

        let parsed = try #require(NIP46.NostrConnectURI(from: uri))

        #expect(parsed.clientPubkey == clientPubkey)
        #expect(parsed.relays == ["wss://relay1.example.com", "wss://relay2.example2.com"])
        #expect(parsed.secret == "0s8j2djs")
        #expect(parsed.name == "My Client")
        #expect(NIP46.parsePermissions(try #require(parsed.permissions)) == [
            NIP46.Permission(method: .nip44Encrypt),
            NIP46.Permission(method: .nip44Decrypt),
            NIP46.Permission(method: .signEvent, kind: 13),
            NIP46.Permission(method: .signEvent, kind: 14),
            NIP46.Permission(method: .signEvent, kind: 1059)
        ])
    }

    @Test("Percent-encoded spaces and escaped pluses in the name are preserved")
    func nameDecoding() throws {
        let uri = "nostrconnect://\(clientPubkey)?relay=wss://relay.example.com&secret=abc&name=My%20Client%2B"

        let parsed = try #require(NIP46.NostrConnectURI(from: uri))

        #expect(parsed.name == "My Client+")
    }

    @Test("nostrconnect URIs round-trip through toString, pluses included")
    func nostrConnectRoundTrip() throws {
        let original = NIP46.NostrConnectURI(
            clientPubkey: clientPubkey,
            relays: ["wss://relay.example.com", "wss://relay2.example.com"],
            secret: "s3cr3t",
            permissions: "sign_event:1,nip44_encrypt",
            name: "Space + Plus",
            url: "https://example.com/app?x=1&y=2",
            image: "https://example.com/icon.png"
        )

        let string = original.toString()
        #expect(string.hasPrefix("nostrconnect://\(clientPubkey)?"))
        #expect(!string.contains("Space + Plus"))

        let parsed = try #require(NIP46.NostrConnectURI(from: string))
        #expect(parsed == original)
    }

    @Test("nostrconnect URIs without a relay or secret are rejected")
    func nostrConnectValidation() {
        #expect(NIP46.NostrConnectURI(from: "nostrconnect://\(clientPubkey)?secret=abc") == nil)
        #expect(NIP46.NostrConnectURI(from: "nostrconnect://\(clientPubkey)?relay=wss://relay.example.com") == nil)
        #expect(NIP46.NostrConnectURI(from: "nostrconnect://\(clientPubkey)?relay=wss://relay.example.com&secret=") == nil)
        #expect(NIP46.NostrConnectURI(from: "bunker://\(clientPubkey)?relay=wss://relay.example.com&secret=abc") == nil)
        #expect(NIP46.NostrConnectURI(from: "nostrconnect://tooshort?relay=wss://relay.example.com&secret=abc") == nil)
    }

    // MARK: - bunker://

    @Test("Parses bunker URIs with both bunker:// and bunker: prefixes")
    func bunkerURIParsing() throws {
        let full = try #require(NIP46.BunkerURI(from: "bunker://\(signerPubkey)?relay=wss://relay.example.com&relay=wss://relay2.example.com&secret=xyz"))
        #expect(full.signerPubkey == signerPubkey)
        #expect(full.relays == ["wss://relay.example.com", "wss://relay2.example.com"])
        #expect(full.secret == "xyz")

        let short = try #require(NIP46.BunkerURI(from: "bunker:\(signerPubkey)?relay=wss://relay.example.com"))
        #expect(short.relays == ["wss://relay.example.com"])
        #expect(short.secret == nil)

        #expect(NIP46.BunkerURI(from: "bunker://\(signerPubkey)") == nil)
    }

    // MARK: - Permissions

    @Test("Permission strings parse and format symmetrically")
    func permissionParsing() throws {
        let scoped = try #require(NIP46.Permission(from: "sign_event:7"))
        #expect(scoped.method == .signEvent)
        #expect(scoped.kind == 7)
        #expect(scoped.toString() == "sign_event:7")

        let plain = try #require(NIP46.Permission(from: "nip44_decrypt"))
        #expect(plain.kind == nil)
        #expect(plain.toString() == "nip44_decrypt")

        #expect(NIP46.Permission(from: "teleport") == nil)
        #expect(NIP46.formatPermissions(NIP46.parsePermissions(" sign_event:1, ping ,bogus")) == "sign_event:1,ping")
    }

    // MARK: - Requests and responses

    @Test("Requests round-trip through an encrypted, signed event")
    func requestRoundTrip() throws {
        let client = try KeyPair.generate()
        let signer = try KeyPair.generate()

        let request = NIP46.connectRequest(
            signerPubkey: signer.publicKey,
            secret: "abc",
            permissions: [NIP46.Permission(method: .signEvent, kind: 1)]
        )
        #expect(request.method == "connect")
        #expect(request.params == [signer.publicKey, "abc", "sign_event:1"])

        let event = try NIP46.createRequestEvent(request: request, signerPubkey: signer.publicKey, clientKeyPair: client)
        #expect(event.kind == EventKind.remoteSigningRequest.rawValue)
        #expect(event.tags == [["p", signer.publicKey]])
        #expect(try KeyPair.verifyEvent(event))

        let plaintext = try signer.decryptNIP44(payload: event.content, from: client.publicKey)
        let decoded = try JSONDecoder().decode(NIP46.Request.self, from: Data(plaintext.utf8))
        #expect(decoded.id == request.id)
        #expect(decoded.method == request.method)
        #expect(decoded.params == request.params)
    }

    @Test("Auth challenges are recognised by their result marker")
    func authChallengeResponse() {
        let challenge = NIP46.Response.authChallenge(id: "req-1", url: "https://signer.example.com/auth")
        #expect(challenge.isAuthChallenge)
        #expect(challenge.authURL == URL(string: "https://signer.example.com/auth"))

        #expect(!NIP46.Response.success(id: "req-2", result: "ack").isAuthChallenge)
        #expect(!NIP46.Response.failure(id: "req-3", error: "unauthorized").isAuthChallenge)
    }
}
