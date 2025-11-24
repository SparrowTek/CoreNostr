import Testing
@testable import CoreNostr

@Suite("NIP-47: Nostr Wallet Connect")
struct NIP47Tests {
    
    @Test("Parses valid NWC URI with relay deduplication and normalization")
    func testValidURIParsing() throws {
        let uriString = "nostr+walletconnect://\(String(repeating: "a", count: 64))?relay=wss://relay1.com&relay=wss://relay1.com&relay=ws://relay2.com&secret=\(String(repeating: "b", count: 64))"
        
        guard let uri = NWCConnectionURI(from: uriString) else {
            Issue.record("Failed to parse valid NWC URI")
            return
        }
        
        #expect(uri.walletPubkey == String(repeating: "a", count: 64))
        #expect(uri.secret == String(repeating: "b", count: 64))
        #expect(uri.relays.count == 2)
        #expect(uri.relays.contains("wss://relay1.com"))
        #expect(uri.relays.contains("ws://relay2.com"))
        
        // Round-trip back to URI
        let regenerated = uri.toURI()
        #expect(regenerated.contains("relay=wss://relay1.com"))
        #expect(regenerated.contains("relay=ws://relay2.com"))
    }
    
    @Test("Rejects malformed NWC URIs")
    func testInvalidURIParsing() throws {
        let missingSecret = "nostr+walletconnect://\(String(repeating: "a", count: 64))?relay=wss://relay.com"
        #expect(NWCConnectionURI(from: missingSecret) == nil)
        
        let badSecretLength = "nostr+walletconnect://\(String(repeating: "a", count: 64))?relay=wss://relay.com&secret=1234"
        #expect(NWCConnectionURI(from: badSecretLength) == nil)
        
        let badPubkey = "nostr+walletconnect://nothex?relay=wss://relay.com&secret=\(String(repeating: "b", count: 64))"
        #expect(NWCConnectionURI(from: badPubkey) == nil)
        
        let invalidRelayScheme = "nostr+walletconnect://\(String(repeating: "a", count: 64))?relay=http://relay.com&secret=\(String(repeating: "b", count: 64))"
        #expect(NWCConnectionURI(from: invalidRelayScheme) == nil)
    }
}
