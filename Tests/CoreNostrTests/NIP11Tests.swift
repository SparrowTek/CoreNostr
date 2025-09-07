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
    
    // MARK: - Extended Encoding/Decoding Tests
    
    @Test("Complete round-trip encoding/decoding")
    func testCompleteRoundTripEncoding() throws {
        // Create a fully populated relay information
        let original = RelayInformation(
            name: "Complete Test Relay",
            description: "A relay with all fields populated",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            contact: "mailto:admin@relay.example.com",
            supportedNips: [1, 2, 4, 5, 9, 11, 12, 13, 15, 16, 20, 22, 26, 28, 33, 40],
            software: "custom-relay",
            version: "2.5.3",
            limitation: RelayLimitation(
                maxMessageLength: 32768,
                maxSubscriptions: 50,
                maxFilters: 200,
                maxLimit: 10000,
                minPowDifficulty: 16,
                authRequired: false,
                paymentRequired: true,
                restrictedWrites: false,
                createdAtLowerLimit: 1609459200,
                createdAtUpperLimit: nil
            ),
            retentionPolicy: [
                RetentionPolicy(time: 86400, kinds: [0, 3]),
                RetentionPolicy(count: 5000, kinds: [1, 2]),
                RetentionPolicy(time: 3600)
            ],
            relayCountries: ["US", "CA", "EU", "JP"],
            languageTags: ["en", "es", "fr", "ja"],
            tags: ["bitcoin", "lightning", "nostr", "verified"],
            postingPolicy: "https://relay.example.com/policy.html",
            paymentsUrl: "https://relay.example.com/payments",
            fees: RelayFees(
                admission: [
                    RelayFee(amount: 5000, unit: "msats"),
                    RelayFee(amount: 5, unit: "USD")
                ],
                subscription: [
                    RelayFee(amount: 1000, unit: "msats", period: 86400),
                    RelayFee(amount: 10000, unit: "msats", period: 2592000)
                ],
                publication: [
                    RelayFee(amount: 100, unit: "msats", kinds: [1, 2]),
                    RelayFee(amount: 500, unit: "msats", kinds: [4]),
                    RelayFee(amount: 1000, unit: "msats", kinds: [7])
                ]
            ),
            icon: "https://relay.example.com/icon.svg"
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let jsonData = try encoder.encode(original)
        
        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RelayInformation.self, from: jsonData)
        
        // Verify all fields match
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.pubkey == original.pubkey)
        #expect(decoded.contact == original.contact)
        #expect(decoded.supportedNips == original.supportedNips)
        #expect(decoded.software == original.software)
        #expect(decoded.version == original.version)
        
        // Verify limitation
        #expect(decoded.limitation?.maxMessageLength == original.limitation?.maxMessageLength)
        #expect(decoded.limitation?.maxSubscriptions == original.limitation?.maxSubscriptions)
        #expect(decoded.limitation?.maxFilters == original.limitation?.maxFilters)
        #expect(decoded.limitation?.maxLimit == original.limitation?.maxLimit)
        #expect(decoded.limitation?.minPowDifficulty == original.limitation?.minPowDifficulty)
        #expect(decoded.limitation?.authRequired == original.limitation?.authRequired)
        #expect(decoded.limitation?.paymentRequired == original.limitation?.paymentRequired)
        #expect(decoded.limitation?.restrictedWrites == original.limitation?.restrictedWrites)
        #expect(decoded.limitation?.createdAtLowerLimit == original.limitation?.createdAtLowerLimit)
        
        // Verify retention policies
        #expect(decoded.retentionPolicy?.count == 3)
        #expect(decoded.retentionPolicy?[0].time == 86400)
        #expect(decoded.retentionPolicy?[0].kinds == [0, 3])
        #expect(decoded.retentionPolicy?[1].count == 5000)
        #expect(decoded.retentionPolicy?[1].kinds == [1, 2])
        
        // Verify arrays
        #expect(decoded.relayCountries == original.relayCountries)
        #expect(decoded.languageTags == original.languageTags)
        #expect(decoded.tags == original.tags)
        
        // Verify URLs
        #expect(decoded.postingPolicy == original.postingPolicy)
        #expect(decoded.paymentsUrl == original.paymentsUrl)
        #expect(decoded.icon == original.icon)
        
        // Verify fees
        #expect(decoded.fees?.admission?.count == 2)
        #expect(decoded.fees?.subscription?.count == 2)
        #expect(decoded.fees?.publication?.count == 3)
    }
    
    @Test("Real-world relay JSON examples")
    func testRealWorldRelayJSON() throws {
        // Example from a Damus-style relay
        let damusStyleJSON = """
        {
            "name": "damus.io",
            "description": "A fast and reliable nostr relay",
            "supported_nips": [1, 2, 4, 9, 11, 12, 15, 16, 20, 22, 26, 28, 33, 40],
            "software": "git+https://github.com/damus-io/strfry.git",
            "version": "0.9.6",
            "limitation": {
                "max_message_length": 1048576,
                "max_subscriptions": 20,
                "max_filters": 100,
                "max_limit": 5000,
                "payment_required": false,
                "auth_required": false
            },
            "relay_countries": ["US"],
            "payments_url": "https://damus.io/purple",
            "fees": {
                "admission": [{"amount": 0, "unit": "msats"}]
            }
        }
        """
        
        let decoder = JSONDecoder()
        let damusRelay = try decoder.decode(RelayInformation.self, from: Data(damusStyleJSON.utf8))
        
        #expect(damusRelay.name == "damus.io")
        #expect(damusRelay.supportedNips?.contains(1) == true)
        #expect(damusRelay.limitation?.maxMessageLength == 1048576)
        #expect(damusRelay.limitation?.paymentRequired == false)
        
        // Example from a paid relay
        let paidRelayJSON = """
        {
            "name": "premium.nostr.wine",
            "description": "Premium paid relay with spam protection",
            "supported_nips": [1, 2, 4, 9, 11, 12, 13, 15, 16, 20, 22, 26, 28, 33, 40, 42],
            "limitation": {
                "max_message_length": 65536,
                "max_subscriptions": 100,
                "payment_required": true,
                "min_pow_difficulty": 0,
                "auth_required": true
            },
            "fees": {
                "admission": [
                    {"amount": 21000, "unit": "sats"}
                ],
                "publication": [
                    {"amount": 0, "unit": "msats"}
                ]
            },
            "payments_url": "https://nostr.wine/invoices"
        }
        """
        
        let paidRelay = try decoder.decode(RelayInformation.self, from: Data(paidRelayJSON.utf8))
        
        #expect(paidRelay.limitation?.paymentRequired == true)
        #expect(paidRelay.limitation?.authRequired == true)
        #expect(paidRelay.fees?.admission?.first?.amount == 21000)
        #expect(paidRelay.fees?.admission?.first?.unit == "sats")
    }
    
    @Test("Malformed JSON handling")
    func testMalformedJSONHandling() throws {
        // Test with various malformed JSON inputs
        let malformedCases = [
            // Invalid JSON syntax
            "{name: \"Invalid\"}",
            // Incomplete JSON
            "{\"name\": \"Test\"",
            // Wrong types
            "{\"supported_nips\": \"not an array\"}",
            "{\"limitation\": \"not an object\"}",
            // Invalid numbers
            "{\"limitation\": {\"max_message_length\": \"not a number\"}}",
        ]
        
        let decoder = JSONDecoder()
        
        for malformed in malformedCases {
            #expect(throws: Error.self) {
                _ = try decoder.decode(RelayInformation.self, from: Data(malformed.utf8))
            }
        }
    }
    
    @Test("Special characters in strings")
    func testSpecialCharactersInStrings() throws {
        let json = """
        {
            "name": "Test \\\"Relay\\\" with 'quotes'",
            "description": "Line 1\\nLine 2\\tTabbed\\r\\nWindows line",
            "contact": "admin@relay.com\\u0020(spaces)",
            "tags": ["emoji-🚀", "unicode-你好", "special-<>&"],
            "posting_policy": "https://example.com/policy?param=value&other=true"
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.name == "Test \"Relay\" with 'quotes'")
        #expect(relayInfo.description?.contains("\\n") == true)
        #expect(relayInfo.tags?.contains("emoji-🚀") == true)
        #expect(relayInfo.tags?.contains("unicode-你好") == true)
        #expect(relayInfo.postingPolicy?.contains("param=value") == true)
    }
    
    @Test("Large numbers and edge cases")
    func testLargeNumbersAndEdgeCases() throws {
        let json = """
        {
            "limitation": {
                "max_message_length": 2147483647,
                "max_subscriptions": 0,
                "max_filters": 999999,
                "max_limit": 1,
                "min_pow_difficulty": 255,
                "created_at_lower_limit": 0,
                "created_at_upper_limit": 9999999999
            },
            "fees": {
                "admission": [
                    {"amount": 9223372036854775807, "unit": "msats"}
                ],
                "subscription": [
                    {"amount": 0, "unit": "sats", "period": 1}
                ]
            }
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.limitation?.maxMessageLength == 2147483647)
        #expect(relayInfo.limitation?.maxSubscriptions == 0)
        #expect(relayInfo.limitation?.minPowDifficulty == 255)
        #expect(relayInfo.fees?.admission?.first?.amount == 9223372036854775807)
        #expect(relayInfo.fees?.subscription?.first?.period == 1)
    }
    
    @Test("Retention policy variations")
    func testRetentionPolicyVariations() throws {
        let json = """
        {
            "retention": [
                {"time": 3600},
                {"count": 1000},
                {"kinds": [0, 3]},
                {"time": 86400, "kinds": [1, 2]},
                {"count": 5000, "kinds": [4, 5, 6]},
                {"time": 7200, "count": 2000},
                {"time": 604800, "count": 10000, "kinds": [30000, 30001]}
            ]
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.retentionPolicy?.count == 7)
        
        // Verify different retention policy types
        let policies = relayInfo.retentionPolicy!
        #expect(policies[0].time == 3600)
        #expect(policies[0].count == nil)
        #expect(policies[0].kinds == nil)
        
        #expect(policies[1].time == nil)
        #expect(policies[1].count == 1000)
        
        #expect(policies[2].kinds == [0, 3])
        
        #expect(policies[5].time == 7200)
        #expect(policies[5].count == 2000)
        
        #expect(policies[6].time == 604800)
        #expect(policies[6].count == 10000)
        #expect(policies[6].kinds == [30000, 30001])
    }
    
    @Test("NIP support array edge cases")
    func testNIPSupportArrayEdgeCases() throws {
        let testCases = [
            // Empty array
            ("{\"supported_nips\": []}", []),
            // Single NIP
            ("{\"supported_nips\": [1]}", [1]),
            // Duplicates (should preserve)
            ("{\"supported_nips\": [1, 1, 2, 2]}", [1, 1, 2, 2]),
            // Out of order
            ("{\"supported_nips\": [99, 1, 50, 2]}", [99, 1, 50, 2]),
            // Large NIP numbers
            ("{\"supported_nips\": [1000, 9999, 65535]}", [1000, 9999, 65535])
        ]
        
        let decoder = JSONDecoder()
        
        for (json, expected) in testCases {
            let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
            #expect(relayInfo.supportedNips == expected)
        }
    }
    
    @Test("URL validation in fields")
    func testURLValidationInFields() throws {
        let json = """
        {
            "contact": "nostr:npub1806cg07tjyx350rljetuhejyl2yr5g8a72c53evya2e44h052wws5z4dze",
            "posting_policy": "http://example.com/policy",
            "payments_url": "https://example.com:8080/pay?user=test",
            "icon": "data:image/svg+xml;base64,PHN2ZyB..."
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        #expect(relayInfo.contact?.hasPrefix("nostr:") == true)
        #expect(relayInfo.postingPolicy?.hasPrefix("http://") == true)
        #expect(relayInfo.paymentsUrl?.contains(":8080") == true)
        #expect(relayInfo.icon?.hasPrefix("data:") == true)
    }
    
    @Test("Fee structure completeness")
    func testFeeStructureCompleteness() throws {
        let json = """
        {
            "fees": {
                "admission": [
                    {"amount": 1000, "unit": "msats"},
                    {"amount": 1, "unit": "USD"},
                    {"amount": 0.00001, "unit": "BTC"}
                ],
                "subscription": [
                    {"amount": 100, "unit": "msats", "period": 3600},
                    {"amount": 1000, "unit": "msats", "period": 86400},
                    {"amount": 5000, "unit": "msats", "period": 604800}
                ],
                "publication": [
                    {"amount": 10, "unit": "msats"},
                    {"amount": 50, "unit": "msats", "kinds": [1]},
                    {"amount": 100, "unit": "msats", "kinds": [4, 5]},
                    {"amount": 500, "unit": "msats", "kinds": [30000, 30001, 30002]}
                ]
            }
        }
        """
        
        let decoder = JSONDecoder()
        let relayInfo = try decoder.decode(RelayInformation.self, from: Data(json.utf8))
        
        let fees = relayInfo.fees!
        
        // Verify admission fees
        #expect(fees.admission?.count == 3)
        #expect(fees.admission?[2].unit == "BTC")
        
        // Verify subscription fees with periods
        #expect(fees.subscription?.count == 3)
        #expect(fees.subscription?[0].period == 3600)
        #expect(fees.subscription?[2].period == 604800)
        
        // Verify publication fees with kinds
        #expect(fees.publication?.count == 4)
        #expect(fees.publication?[0].kinds == nil)
        #expect(fees.publication?[1].kinds == [1])
        #expect(fees.publication?[3].kinds == [30000, 30001, 30002])
    }
}