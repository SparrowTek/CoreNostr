import Testing
import Foundation
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

    // MARK: - Enum Decoding Resilience

    @Test("NWCErrorCode decodes known values")
    func testErrorCodeKnownValues() throws {
        let json = Data(#""RATE_LIMITED""#.utf8)
        let decoded = try JSONDecoder().decode(NWCErrorCode.self, from: json)
        #expect(decoded == .rateLimited)
        #expect(decoded.rawValue == "RATE_LIMITED")
    }

    @Test("NWCErrorCode decodes unknown values into .unknown case")
    func testErrorCodeUnknownValue() throws {
        let json = Data(#""SOME_FUTURE_ERROR""#.utf8)
        let decoded = try JSONDecoder().decode(NWCErrorCode.self, from: json)
        #expect(decoded == .unknown("SOME_FUTURE_ERROR"))
        #expect(decoded.rawValue == "SOME_FUTURE_ERROR")
    }

    @Test("NWCErrorCode round-trips through encode/decode")
    func testErrorCodeRoundTrip() throws {
        let codes: [NWCErrorCode] = [.rateLimited, .unauthorized, .other, .unknown("CUSTOM")]
        for code in codes {
            let data = try JSONEncoder().encode(code)
            let decoded = try JSONDecoder().decode(NWCErrorCode.self, from: data)
            #expect(decoded == code)
        }
    }

    @Test("NWCTransactionType decodes unknown values into .unknown case")
    func testTransactionTypeUnknownValue() throws {
        let json = Data(#""refund""#.utf8)
        let decoded = try JSONDecoder().decode(NWCTransactionType.self, from: json)
        #expect(decoded == .unknown("refund"))
        #expect(decoded.rawValue == "refund")
    }

    @Test("NWCTransactionType round-trips through encode/decode")
    func testTransactionTypeRoundTrip() throws {
        let types: [NWCTransactionType] = [.incoming, .outgoing, .unknown("custom")]
        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(NWCTransactionType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test("NWCTransactionState decodes unknown values into .unknown case")
    func testTransactionStateUnknownValue() throws {
        let json = Data(#""processing""#.utf8)
        let decoded = try JSONDecoder().decode(NWCTransactionState.self, from: json)
        #expect(decoded == .unknown("processing"))
        #expect(decoded.rawValue == "processing")
    }

    @Test("NWCTransactionState round-trips through encode/decode")
    func testTransactionStateRoundTrip() throws {
        let states: [NWCTransactionState] = [.pending, .settled, .expired, .failed, .unknown("custom")]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(NWCTransactionState.self, from: data)
            #expect(decoded == state)
        }
    }

    // MARK: - NWCTransaction Decoding Resilience

    @Test("NWCTransaction decodes with all fields present")
    func testTransactionFullDecode() throws {
        let json = """
        {
            "type": "incoming",
            "state": "settled",
            "invoice": "lnbc50n1...",
            "description": "test payment",
            "description_hash": "abc123",
            "preimage": "deadbeef",
            "payment_hash": "hash123",
            "amount": 50000,
            "fees_paid": 100,
            "created_at": 1693876973,
            "expires_at": 1693880573,
            "settled_at": 1693877000,
            "metadata": {"key": "value"}
        }
        """.data(using: .utf8)!

        let tx = try JSONDecoder().decode(NWCTransaction.self, from: json)
        #expect(tx.type == .incoming)
        #expect(tx.state == .settled)
        #expect(tx.paymentHash == "hash123")
        #expect(tx.amount == 50000)
        #expect(tx.feesPaid == 100)
        #expect(tx.invoice == "lnbc50n1...")
    }

    @Test("NWCTransaction decodes with missing optional fields")
    func testTransactionMinimalDecode() throws {
        let json = """
        {
            "type": "outgoing",
            "amount": 1000,
            "created_at": 1693876973
        }
        """.data(using: .utf8)!

        let tx = try JSONDecoder().decode(NWCTransaction.self, from: json)
        #expect(tx.type == .outgoing)
        #expect(tx.state == nil)
        #expect(tx.paymentHash == nil)
        #expect(tx.amount == 1000)
        #expect(tx.invoice == nil)
        #expect(tx.feesPaid == nil)
        #expect(tx.metadata == nil)
    }

    @Test("NWCTransaction decodes with unknown type and state values")
    func testTransactionUnknownEnumValues() throws {
        let json = """
        {
            "type": "refund",
            "state": "processing",
            "payment_hash": "hash456",
            "amount": 2000,
            "created_at": 1693876973
        }
        """.data(using: .utf8)!

        let tx = try JSONDecoder().decode(NWCTransaction.self, from: json)
        #expect(tx.type == .unknown("refund"))
        #expect(tx.state == .unknown("processing"))
    }

    // MARK: - NWCResponse Decoding Resilience

    @Test("NWCResponse decodes with unknown error code")
    func testResponseUnknownErrorCode() throws {
        let json = """
        {
            "result_type": "pay_invoice",
            "error": {
                "code": "BUDGET_EXCEEDED",
                "message": "Monthly budget reached"
            },
            "result": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NWCResponse.self, from: json)
        #expect(response.error?.code == .unknown("BUDGET_EXCEEDED"))
        #expect(response.error?.message == "Monthly budget reached")
        #expect(response.result == nil)
    }

    // MARK: - URI Interop

    @Test("Parses slash-less NWC URI variant")
    func testSlashlessURIParsing() throws {
        let pubkey = String(repeating: "a", count: 64)
        let secret = String(repeating: "b", count: 64)
        let uriString = "nostr+walletconnect:\(pubkey)?relay=wss%3A%2F%2Frelay.damus.io&secret=\(secret)"

        guard let uri = NWCConnectionURI(from: uriString) else {
            Issue.record("Failed to parse slash-less NWC URI")
            return
        }

        #expect(uri.walletPubkey == pubkey)
        #expect(uri.secret == secret)
        #expect(uri.relays == ["wss://relay.damus.io"])
    }

    // MARK: - Request Encoding

    @Test("Request without params still encodes an empty params object")
    func testRequestAlwaysIncludesParams() throws {
        let clientKeyPair = try KeyPair.generate()
        let walletKeyPair = try KeyPair.generate()

        let event = try NostrEvent.nwcRequest(
            method: .getBalance,
            params: nil,
            walletPubkey: walletKeyPair.publicKey,
            clientSecret: clientKeyPair.privateKey,
            encryption: .nip44
        )

        let decrypted = try event.decryptNWCContent(
            with: walletKeyPair.privateKey,
            peerPubkey: clientKeyPair.publicKey
        )

        let json = try JSONSerialization.jsonObject(with: Data(decrypted.utf8)) as? [String: Any]
        #expect(json?["method"] as? String == "get_balance")
        #expect(json?["params"] as? [String: Any] != nil, "params key must be present as an object")
    }

    // MARK: - AnyCodable Numeric Support

    @Test("AnyCodable encodes and decodes UInt64 values (keysend TLV types)")
    func testAnyCodableUInt64() throws {
        // TLV record types are u64 and can exceed Int64.max
        let tlvType: UInt64 = 5_482_373_484
        let encoded = try JSONEncoder().encode(["type": AnyCodable(tlvType)])
        let jsonString = String(decoding: encoded, as: UTF8.self)
        #expect(jsonString.contains("5482373484"))

        let large: UInt64 = UInt64(Int64.max) + 1
        let encodedLarge = try JSONEncoder().encode(["type": AnyCodable(large)])
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: encodedLarge)
        #expect(decoded["type"]?.value as? UInt64 == large)
    }

    @Test("AnyCodable encodes nested AnyCodable structures (multi_pay params shape)")
    func testAnyCodableNestedWrappers() throws {
        // multi_pay_invoice params: an AnyCodable wrapping [[String: AnyCodable]]
        let invoices: [[String: AnyCodable]] = [
            ["invoice": AnyCodable("lnbc1"), "id": AnyCodable("a")],
            ["invoice": AnyCodable("lnbc2"), "amount": AnyCodable(Int64(123))]
        ]
        let params: [String: AnyCodable] = ["invoices": AnyCodable(invoices)]

        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let decodedInvoices = json?["invoices"] as? [[String: Any]]

        #expect(decodedInvoices?.count == 2)
        #expect(decodedInvoices?.first?["invoice"] as? String == "lnbc1")

        // Directly nested wrapper unwraps rather than throwing
        let nested = try JSONEncoder().encode(AnyCodable(AnyCodable("x")))
        #expect(String(decoding: nested, as: UTF8.self) == #""x""#)
    }
}
