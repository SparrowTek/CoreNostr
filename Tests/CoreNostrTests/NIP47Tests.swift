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
}
