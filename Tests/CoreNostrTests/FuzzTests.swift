import Testing
import Foundation
@testable import CoreNostr

@Suite("Fuzz Tests: Malformed input and boundary conditions")
struct FuzzTests {
    
    // MARK: - JSON Decoder Fuzz Tests
    
    @Test("Malformed JSON event structures")
    func testMalformedJSONEvents() throws {
        let decoder = JSONDecoder()
        
        let malformedJSONs = [
            // Missing required fields
            """
            {"pubkey": "abc", "kind": 1}
            """,
            
            // Wrong types
            """
            {
                "id": 123,
                "pubkey": "abc",
                "created_at": "not a number",
                "kind": "text",
                "tags": "not an array",
                "content": null,
                "sig": true
            }
            """,
            
            // Truncated JSON
            """
            {
                "id": "abc",
                "pubkey": "def",
                "created_at": 1234567890,
                "kind": 1,
                "tags": [["e", "test"]
            """,
            
            // Extra closing brackets
            """
            {
                "id": "abc",
                "pubkey": "def",
                "created_at": 1234567890,
                "kind": 1,
                "tags": [],
                "content": "test",
                "sig": "xyz"
            }}}
            """,
            
            // Nested objects where arrays expected
            """
            {
                "id": "abc",
                "pubkey": "def",
                "created_at": 1234567890,
                "kind": 1,
                "tags": {"key": "value"},
                "content": "test",
                "sig": "xyz"
            }
            """,
            
            // Unicode control characters
            """
            {
                "id": "abc",
                "pubkey": "def",
                "created_at": 1234567890,
                "kind": 1,
                "tags": [],
                "content": "test\\u0000null\\u0001soh",
                "sig": "xyz"
            }
            """,
            
            // Extremely nested structure
            """
            {
                "id": "abc",
                "pubkey": "def",
                "created_at": 1234567890,
                "kind": 1,
                "tags": [[[[[[[[[[[[[[[[[[[[["deeply", "nested"]]]]]]]]]]]]]]]]]]]]],
                "content": "test",
                "sig": "xyz"
            }
            """
        ]
        
        for json in malformedJSONs {
            #expect(throws: Error.self) {
                _ = try decoder.decode(NostrEvent.self, from: Data(json.utf8))
            }
        }
    }
    
    @Test("Boundary size JSON events")
    func testBoundarySizeJSONEvents() throws {
        let decoder = JSONDecoder()
        
        // Empty content
        let emptyContent = """
        {
            "id": "\(String(repeating: "0", count: 64))",
            "pubkey": "\(String(repeating: "0", count: 64))",
            "created_at": 0,
            "kind": 0,
            "tags": [],
            "content": "",
            "sig": "\(String(repeating: "0", count: 128))"
        }
        """
        
        let emptyEvent = try decoder.decode(NostrEvent.self, from: Data(emptyContent.utf8))
        #expect(emptyEvent.content.isEmpty)
        
        // Very large content (but still valid)
        let largeContent = String(repeating: "x", count: 10000)
        let largeJSON = """
        {
            "id": "\(String(repeating: "0", count: 64))",
            "pubkey": "\(String(repeating: "0", count: 64))",
            "created_at": 0,
            "kind": 1,
            "tags": [],
            "content": "\(largeContent)",
            "sig": "\(String(repeating: "0", count: 128))"
        }
        """
        
        let largeEvent = try decoder.decode(NostrEvent.self, from: Data(largeJSON.utf8))
        #expect(largeEvent.content.count == 10000)
        
        // Maximum integer values
        let maxIntJSON = """
        {
            "id": "\(String(repeating: "f", count: 64))",
            "pubkey": "\(String(repeating: "f", count: 64))",
            "created_at": 9223372036854775807,
            "kind": 65535,
            "tags": [],
            "content": "max values",
            "sig": "\(String(repeating: "f", count: 128))"
        }
        """
        
        let maxEvent = try decoder.decode(NostrEvent.self, from: Data(maxIntJSON.utf8))
        #expect(maxEvent.createdAt == 9223372036854775807)
        #expect(maxEvent.kind == 65535)
        
        // Negative values (should handle or reject appropriately)
        let negativeJSON = """
        {
            "id": "\(String(repeating: "0", count: 64))",
            "pubkey": "\(String(repeating: "0", count: 64))",
            "created_at": -1,
            "kind": -1,
            "tags": [],
            "content": "negative",
            "sig": "\(String(repeating: "0", count: 128))"
        }
        """
        
        // This might decode but validation should catch it
        let negativeEvent = try decoder.decode(NostrEvent.self, from: Data(negativeJSON.utf8))
        #expect(negativeEvent.createdAt == -1)
        #expect(negativeEvent.kind == -1)
    }
    
    @Test("Malformed tag structures")
    func testMalformedTags() throws {
        let decoder = JSONDecoder()
        
        let tagTestCases: [(json: String, shouldFail: Bool)] = [
            // Empty tags array
            ("""
            {
                "id": "\(String(repeating: "0", count: 64))",
                "pubkey": "\(String(repeating: "0", count: 64))",
                "created_at": 1000000,
                "kind": 1,
                "tags": [],
                "content": "test",
                "sig": "\(String(repeating: "0", count: 128))"
            }
            """, false),
            
            // Tags with various types mixed
            ("""
            {
                "id": "\(String(repeating: "0", count: 64))",
                "pubkey": "\(String(repeating: "0", count: 64))",
                "created_at": 1000000,
                "kind": 1,
                "tags": [["e", "test"], [123, 456], ["p", null]],
                "content": "test",
                "sig": "\(String(repeating: "0", count: 128))"
            }
            """, true),
            
            // Very deeply nested tags
            ("""
            {
                "id": "\(String(repeating: "0", count: 64))",
                "pubkey": "\(String(repeating: "0", count: 64))",
                "created_at": 1000000,
                "kind": 1,
                "tags": [["tag", ["nested", ["more", ["deep"]]]]],
                "content": "test",
                "sig": "\(String(repeating: "0", count: 128))"
            }
            """, true),
            
            // Extremely long tag arrays
            ("""
            {
                "id": "\(String(repeating: "0", count: 64))",
                "pubkey": "\(String(repeating: "0", count: 64))",
                "created_at": 1000000,
                "kind": 1,
                "tags": [[\(Array(repeating: "\"x\"", count: 1000).joined(separator: ","))]],
                "content": "test",
                "sig": "\(String(repeating: "0", count: 128))"
            }
            """, false), // This should succeed but be very large
            
            // Empty tag arrays
            ("""
            {
                "id": "\(String(repeating: "0", count: 64))",
                "pubkey": "\(String(repeating: "0", count: 64))",
                "created_at": 1000000,
                "kind": 1,
                "tags": [[]],
                "content": "test",
                "sig": "\(String(repeating: "0", count: 128))"
            }
            """, false) // Empty tags are technically valid JSON
        ]
        
        for (json, shouldFail) in tagTestCases {
            if shouldFail {
                #expect(throws: Error.self) {
                    _ = try decoder.decode(NostrEvent.self, from: Data(json.utf8))
                }
            } else {
                // Should decode successfully
                let event = try decoder.decode(NostrEvent.self, from: Data(json.utf8))
                #expect(event.kind == 1)
            }
        }
    }
    
    @Test("Filter JSON fuzzing")
    func testFilterJSONFuzzing() throws {
        let decoder = JSONDecoder()
        
        let malformedFilters = [
            // Wrong types for arrays
            """
            {
                "ids": "not an array",
                "authors": 123,
                "kinds": true
            }
            """,
            
            // Mixed types in arrays
            """
            {
                "ids": ["valid", 123, null],
                "kinds": [1, "two", 3]
            }
            """,
            
            // Invalid time values
            """
            {
                "since": "yesterday",
                "until": "tomorrow"
            }
            """,
            
            // Extremely large numbers
            """
            {
                "kinds": [999999999999999999999999999],
                "limit": 999999999999999999999999999
            }
            """,
            
            // Negative values where not expected
            """
            {
                "kinds": [-1, -100, -9999],
                "limit": -50,
                "since": -1000000
            }
            """
        ]
        
        for json in malformedFilters {
            // These should all fail to decode properly
            #expect(throws: Error.self) {
                _ = try decoder.decode(Filter.self, from: Data(json.utf8))
            }
        }
    }
    
    // MARK: - Hex String Fuzz Tests
    
    @Test("Fuzz hex string parsing")
    func testFuzzHexStringParsing() throws {
        let fuzzInputs = [
            // Valid hex
            "0123456789abcdef",
            "ABCDEF",
            
            // Invalid characters
            "ghijklmnop",
            "0x123456", // With prefix
            "123 456", // With spaces
            "12-34-56", // With dashes
            
            // Odd length
            "123",
            "12345",
            
            // Empty and whitespace
            "",
            " ",
            "\n",
            "\t",
            
            // Unicode
            "🚀",
            "你好",
            "مرحبا",
            
            // Control characters
            "\0",
            "\u{0001}",
            "\u{001F}",
            
            // Very long strings
            String(repeating: "a", count: 10000),
            String(repeating: "0", count: 100000),
            
            // Mixed valid/invalid
            "12g34h56",
            "abc...def",
            "123\n456"
        ]
        
        for input in fuzzInputs {
            let data = Foundation.Data(hex: input)
            
            if input.count % 2 != 0 || !input.allSatisfy({ $0.isHexDigit }) {
                // Should fail for invalid hex
                #expect(data == nil)
            } else if !input.isEmpty {
                // Should succeed for valid hex
                #expect(data != nil)
                #expect(data?.count == input.count / 2)
            }
        }
    }
    
    // MARK: - Bech32 Fuzz Tests
    
    @Test("Fuzz bech32 decoding")
    func testFuzzBech32Decoding() throws {
        let fuzzInputs = [
            // Valid-looking but wrong
            "npub1invalid",
            "nsec1wrong",
            "note1bad",
            
            // Wrong HRP
            "xpub1234567890",
            "btc1234567890",
            
            // Invalid characters
            "npub1234567890!@#$%",
            "npub1234567890 space",
            "npub1234567890\n",
            
            // Mixed case (bech32 should be lowercase)
            "NPUB1234567890",
            "nPuB1234567890",
            
            // Too short
            "npub1",
            "n",
            "",
            
            // Too long (over 1000 chars)
            "npub1" + String(repeating: "q", count: 1000),
            
            // Missing separator
            "npubabcdefghijk",
            
            // Invalid checksum
            "npub1806cg07tjyx350rljetuhejyl2yr5g8a72c53evya2e44h052wws5z4dzx", // Last char wrong
            
            // Unicode
            "npub1🚀",
            "nsec1你好",
            
            // SQL injection attempts (should be safely handled)
            "npub1'; DROP TABLE events; --",
            "nsec1\"; DELETE FROM users; --"
        ]
        
        for input in fuzzInputs {
            // All of these should fail gracefully
            #expect(throws: Error.self) {
                _ = try Bech32Entity(from: input)
            }
        }
    }
    
    // MARK: - Event Builder Fuzz Tests
    
    @Test("EventBuilder with extreme inputs")
    func testEventBuilderExtremeInputs() throws {
        let keyPair = try KeyPair.generate()
        
        // Test with very long content
        let longContent = String(repeating: "x", count: 100000)
        let longEvent = try EventBuilder.text(longContent)
            .buildUnsigned(pubkey: keyPair.publicKey)
        #expect(longEvent.content.count == 100000)
        
        // Test with many tags
        var builder = EventBuilder.text("Many tags")
        for i in 0..<1000 {
            builder = builder.hashtag("tag\(i)")
        }
        let manyTagsEvent = try builder.buildUnsigned(pubkey: keyPair.publicKey)
        #expect(manyTagsEvent.tags.count == 1000)
        
        // Test with Unicode content
        let unicodeContent = "🚀 Hello 你好 مرحبا שלום 🌍"
        let unicodeEvent = try EventBuilder.text(unicodeContent)
            .buildUnsigned(pubkey: keyPair.publicKey)
        #expect(unicodeEvent.content == unicodeContent)
        
        // Test with empty content
        let emptyEvent = try EventBuilder.text("")
            .buildUnsigned(pubkey: keyPair.publicKey)
        #expect(emptyEvent.content.isEmpty)
        
        // Test with control characters
        let controlChars = "Line 1\nLine 2\tTabbed\rCarriage\0Null"
        let controlEvent = try EventBuilder.text(controlChars)
            .buildUnsigned(pubkey: keyPair.publicKey)
        #expect(controlEvent.content == controlChars)
    }
    
    // MARK: - Timestamp Fuzz Tests
    
    @Test("Timestamp boundary conditions")
    func testTimestampBoundaries() throws {
        let testTimestamps: [Int64] = [
            0, // Unix epoch
            -1, // Before epoch
            Int64.min, // Minimum int64
            Int64.max, // Maximum int64
            946684800, // Y2K
            2147483647, // 32-bit max (Y2038 problem)
            1000000000000, // Milliseconds instead of seconds
            1700000000, // Recent reasonable timestamp
        ]
        
        for timestamp in testTimestamps {
            let event = NostrEvent(
                pubkey: String(repeating: "0", count: 64),
                createdAt: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                kind: 1,
                tags: [],
                content: "Test"
            )
            
            #expect(event.createdAt == timestamp)
            
            // Test validation
            if timestamp < 0 || timestamp > Int64(Date().timeIntervalSince1970 + 31536000) {
                #expect(throws: Error.self) {
                    try Validation.validateTimestamp(timestamp)
                }
            }
        }
    }
}