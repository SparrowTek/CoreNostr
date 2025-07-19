import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-11: Relay Information Document Tests")
struct NIP11Tests {
    
    @Test("RelayInformation JSON encoding/decoding")
    func testRelayInformationCoding() throws {
        let relayInfo = RelayInformation(
            name: "Test Relay",
            description: "A test relay for Nostr",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            contact: "admin@testrelay.com",
            supportedNips: [1, 2, 4, 9, 11, 12, 15, 16, 20, 22],
            software: "test-relay",
            version: "1.0.0",
            limitation: RelayLimitation(
                maxMessageLength: 16384,
                maxSubscriptions: 20,
                maxFilters: 100,
                maxLimit: 5000,
                authRequired: false,
                paymentRequired: false
            ),
            retentionPolicy: [
                RetentionPolicy(time: 3600, kinds: [0, 3]),
                RetentionPolicy(count: 1000, kinds: [1])
            ],
            relayCountries: ["US", "CA"],
            languageTags: ["en", "es"],
            tags: ["bitcoin", "lightning"],
            postingPolicy: "https://testrelay.com/policy",
            paymentsUrl: "https://testrelay.com/payments",
            fees: RelayFees(
                admission: [RelayFee(amount: 1000, unit: "msats")],
                publication: [RelayFee(amount: 100, unit: "msats", kinds: [4])]
            ),
            icon: "https://testrelay.com/icon.png"
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(relayInfo)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Verify JSON structure
        #expect(jsonString.contains("\"name\":\"Test Relay\""))
        #expect(jsonString.contains("\"supported_nips\":[1,2,4,9,11,12,15,16,20,22]"))
        #expect(jsonString.contains("\"max_message_length\":16384"))
        #expect(jsonString.contains("\"relay_countries\":[\"US\",\"CA\"]"))
        
        // Decode back
        let decoder = JSONDecoder()
        let decodedInfo = try decoder.decode(RelayInformation.self, from: jsonData)
        
        #expect(decodedInfo.name == relayInfo.name)
        #expect(decodedInfo.supportedNips == relayInfo.supportedNips)
        #expect(decodedInfo.limitation?.maxMessageLength == 16384)
        #expect(decodedInfo.fees?.publication?.first?.amount == 100)
    }
    
    @Test("RelayInformation minimal JSON")
    func testMinimalRelayInformation() throws {
        // Test with minimal required fields
        let json = """
        {
            "name": "Minimal Relay",
            "description": "A minimal relay"
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.name == "Minimal Relay")
        #expect(relayInfo.description == "A minimal relay")
        #expect(relayInfo.supportedNips == nil)
        #expect(relayInfo.limitation == nil)
    }
    
    @Test("RelayLimitation functionality")
    func testRelayLimitation() {
        let limitation = RelayLimitation(
            maxMessageLength: 65536,
            maxSubscriptions: 10,
            maxFilters: 50,
            minPowDifficulty: 20,
            authRequired: true,
            paymentRequired: false,
            restrictedWrites: true,
            createdAtLowerLimit: 1600000000,
            createdAtUpperLimit: 2000000000
        )
        
        #expect(limitation.maxMessageLength == 65536)
        #expect(limitation.authRequired == true)
        #expect(limitation.minPowDifficulty == 20)
        #expect(limitation.restrictedWrites == true)
    }
    
    @Test("RetentionPolicy functionality")
    func testRetentionPolicy() {
        let timePolicy = RetentionPolicy(time: 86400) // 24 hours
        let countPolicy = RetentionPolicy(count: 10000)
        let kindsPolicy = RetentionPolicy(time: 3600, kinds: [0, 1, 2])
        
        #expect(timePolicy.time == 86400)
        #expect(timePolicy.count == nil)
        #expect(timePolicy.kinds == nil)
        
        #expect(countPolicy.count == 10000)
        #expect(countPolicy.time == nil)
        
        #expect(kindsPolicy.time == 3600)
        #expect(kindsPolicy.kinds == [0, 1, 2])
    }
    
    @Test("RelayFees structure")
    func testRelayFees() {
        let fees = RelayFees(
            admission: [
                RelayFee(amount: 5000, unit: "msats"),
                RelayFee(amount: 1, unit: "USD")
            ],
            subscription: [
                RelayFee(amount: 1000, unit: "msats", period: 86400)
            ],
            publication: [
                RelayFee(amount: 100, unit: "msats", kinds: [1]),
                RelayFee(amount: 500, unit: "msats", kinds: [4])
            ]
        )
        
        #expect(fees.admission?.count == 2)
        #expect(fees.admission?[0].amount == 5000)
        #expect(fees.admission?[0].unit == "msats")
        #expect(fees.subscription?[0].period == 86400)
        #expect(fees.publication?[1].kinds == [4])
    }
    
    @Test("Helper methods")
    func testHelperMethods() {
        let relayInfo = RelayInformation(
            name: "Test Relay",
            supportedNips: [1, 2, 9, 11],
            limitation: RelayLimitation(
                minPowDifficulty: 15,
                authRequired: true,
                paymentRequired: false
            ),
            fees: RelayFees(
                admission: [RelayFee(amount: 1000, unit: "msats")]
            )
        )
        
        // Test NIP support checking
        #expect(relayInfo.supports(nip: 1))
        #expect(relayInfo.supports(nip: 11))
        #expect(!relayInfo.supports(nip: 99))
        
        // Test limitation checks
        #expect(relayInfo.hasLimitations)
        #expect(relayInfo.requiresAuth)
        #expect(relayInfo.requiresPayment) // Has fees
        #expect(relayInfo.minimumPoWDifficulty == 15)
        
        // Test without limitations
        let unlimitedRelay = RelayInformation(name: "Unlimited")
        #expect(!unlimitedRelay.hasLimitations)
        #expect(!unlimitedRelay.requiresAuth)
        #expect(!unlimitedRelay.requiresPayment)
        #expect(unlimitedRelay.minimumPoWDifficulty == nil)
    }
    
    @Test("Common NIP support checking")
    func testCommonNIPSupport() {
        let relayInfo = RelayInformation(
            name: "Test Relay",
            supportedNips: [1, 2, 5, 9, 10, 11, 13]
        )
        
        #expect(relayInfo.supports(.basicProtocol))
        #expect(relayInfo.supports(.followLists))
        #expect(relayInfo.supports(.dns))
        #expect(relayInfo.supports(.eventDeletion))
        #expect(relayInfo.supports(.replyThreading))
        #expect(relayInfo.supports(.relayInfo))
        #expect(relayInfo.supports(.proofOfWork))
        
        #expect(!relayInfo.supports(.openTimestamps))
        #expect(!relayInfo.supports(.encryptedDM))
        #expect(!relayInfo.supports(.webAuth))
    }
    
    @Test("JSON with snake_case fields")
    func testSnakeCaseJSON() throws {
        let json = """
        {
            "name": "Snake Case Relay",
            "supported_nips": [1, 2, 3],
            "limitation": {
                "max_message_length": 32768,
                "max_subscriptions": 50,
                "auth_required": true,
                "payment_required": false,
                "min_pow_difficulty": 10,
                "created_at_lower_limit": 1600000000
            },
            "retention": [
                {"time": 3600, "kinds": [0]}
            ],
            "relay_countries": ["US"],
            "language_tags": ["en"],
            "posting_policy": "https://example.com/policy",
            "payments_url": "https://example.com/pay"
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.name == "Snake Case Relay")
        #expect(relayInfo.supportedNips == [1, 2, 3])
        #expect(relayInfo.limitation?.maxMessageLength == 32768)
        #expect(relayInfo.limitation?.authRequired == true)
        #expect(relayInfo.limitation?.minPowDifficulty == 10)
        #expect(relayInfo.retentionPolicy?.first?.time == 3600)
        #expect(relayInfo.relayCountries == ["US"])
        #expect(relayInfo.languageTags == ["en"])
        #expect(relayInfo.postingPolicy == "https://example.com/policy")
        #expect(relayInfo.paymentsUrl == "https://example.com/pay")
    }
    
    @Test("Empty relay information")
    func testEmptyRelayInformation() throws {
        let json = "{}"
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.name == nil)
        #expect(relayInfo.description == nil)
        #expect(relayInfo.supportedNips == nil)
        #expect(!relayInfo.hasLimitations)
        #expect(!relayInfo.requiresAuth)
        #expect(!relayInfo.requiresPayment)
    }
}