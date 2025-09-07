import Testing
import Foundation
@testable import CoreNostr

@Suite("Validation: Comprehensive validation and ergonomics")
struct ValidationTests {
    
    // MARK: - Hex Validation Tests
    
    @Test("Hex string validation with specific lengths")
    func testHexValidation() {
        // Valid 64-char hex (public key, event ID)
        let validPubkey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        #expect(Validation.isValidHex(validPubkey, length: 64))
        
        // Valid 128-char hex (signature)
        let validSig = validPubkey + validPubkey
        #expect(Validation.isValidHex(validSig, length: 128))
        
        // Invalid length
        #expect(!Validation.isValidHex("abc123", length: 64))
        
        // Invalid characters
        #expect(!Validation.isValidHex("xyz0000000000000000000000000000000000000000000000000000000000000", length: 64))
        
        // Case insensitive
        let upperHex = "3BF0C63FCB93463407AF97A5E5EE64FA883D107EF9E558472C4EB9AAAEFA459D"
        #expect(Validation.isValidHex(upperHex, length: 64))
    }
    
    @Test("Hex validation throws appropriate errors")
    func testHexValidationThrows() throws {
        // Too short
        #expect(throws: NostrError.self) {
            try Validation.validateHex("abc", length: 64, field: "pubkey")
        }
        
        // Invalid characters
        #expect(throws: NostrError.self) {
            try Validation.validateHex("ghijklmnop", length: 10, field: "test")
        }
    }
    
    // MARK: - Timestamp Validation Tests
    
    @Test("Timestamp validation with skew limits")
    func testTimestampValidation() {
        let now = Int64(Date().timeIntervalSince1970)
        
        // Current timestamp should be valid
        #expect(Validation.isValidTimestamp(now))
        
        // 5 minutes in future should be valid (within 15 min default)
        let fiveMinFuture = now + 300
        #expect(Validation.isValidTimestamp(fiveMinFuture))
        
        // 20 minutes in future should be invalid
        let twentyMinFuture = now + 1200
        #expect(!Validation.isValidTimestamp(twentyMinFuture))
        
        // 6 months ago should be valid (within 1 year default)
        let sixMonthsAgo = now - (180 * 24 * 60 * 60)
        #expect(Validation.isValidTimestamp(sixMonthsAgo))
        
        // 2 years ago should be invalid
        let twoYearsAgo = now - (2 * 365 * 24 * 60 * 60)
        #expect(!Validation.isValidTimestamp(twoYearsAgo))
        
        // Custom skew limits
        #expect(Validation.isValidTimestamp(now + 30, maxFutureSkew: 60))
        #expect(!Validation.isValidTimestamp(now + 90, maxFutureSkew: 60))
    }
    
    @Test("Timestamp validation throws with details")
    func testTimestampValidationThrows() throws {
        let now = Int64(Date().timeIntervalSince1970)
        
        // Too far in future
        let farFuture = now + 10000
        #expect(throws: NostrError.self) {
            try Validation.validateTimestamp(farFuture)
        }
        
        // Too far in past
        let farPast = now - (2 * 365 * 24 * 60 * 60)
        #expect(throws: NostrError.self) {
            try Validation.validateTimestamp(farPast)
        }
    }
    
    // MARK: - Tag Schema Validation Tests
    
    @Test("Tag schema validation for common tags")
    func testCommonTagValidation() throws {
        // Valid e tag
        let validEventId = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        try Validation.validateTagSchema(tags: [["e", validEventId]], for: 1)
        
        // Valid e tag with relay
        try Validation.validateTagSchema(tags: [["e", validEventId, "wss://relay.example.com"]], for: 1)
        
        // Valid e tag with relay and marker
        try Validation.validateTagSchema(tags: [["e", validEventId, "wss://relay.example.com", "reply"]], for: 1)
        
        // Invalid e tag (bad event ID)
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [["e", "not-valid"]], for: 1)
        }
        
        // Invalid e tag marker
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [["e", validEventId, "", "invalid-marker"]], for: 1)
        }
        
        // Valid p tag
        let validPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        try Validation.validateTagSchema(tags: [["p", validPubkey]], for: 1)
        
        // Invalid p tag (bad pubkey)
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [["p", "invalid"]], for: 1)
        }
        
        // Empty tag
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [[]], for: 1)
        }
    }
    
    @Test("Tag schema validation for kind-specific requirements")
    func testKindSpecificTagValidation() throws {
        let validPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        // Kind 4 (DM) must have exactly one p tag
        try Validation.validateTagSchema(tags: [["p", validPubkey]], for: 4)
        
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [], for: 4)
        }
        
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [["p", validPubkey], ["p", validPubkey]], for: 4)
        }
        
        // Parameterized replaceable (30000-39999) must have d tag
        try Validation.validateTagSchema(tags: [["d", "identifier"]], for: 30023)
        
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(tags: [], for: 30023)
        }
    }
    
    @Test("Complex tag validation scenarios")
    func testComplexTagValidation() throws {
        // Delegation tag
        let validPubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        try Validation.validateTagSchema(
            tags: [["delegation", validPubkey, "kind=1", "sig123"]],
            for: 1
        )
        
        // Invalid delegation (missing fields)
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(
                tags: [["delegation", validPubkey]],
                for: 1
            )
        }
        
        // Nonce tag for PoW
        try Validation.validateTagSchema(
            tags: [["nonce", "12345", "16"]],
            for: 1
        )
        
        // Invalid nonce (missing difficulty)
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(
                tags: [["nonce", "12345"]],
                for: 1
            )
        }
        
        // Address tag (a tag)
        try Validation.validateTagSchema(
            tags: [["a", "30023:author-pubkey:d-tag-value"]],
            for: 1
        )
        
        // Invalid address format
        #expect(throws: NostrError.self) {
            try Validation.validateTagSchema(
                tags: [["a", "invalid-format"]],
                for: 1
            )
        }
    }
    
    // MARK: - URL Validation Tests
    
    @Test("Relay URL validation")
    func testRelayURLValidation() {
        // Valid URLs
        #expect(Validation.isValidRelayURL("wss://relay.example.com"))
        #expect(Validation.isValidRelayURL("ws://localhost:8080"))
        #expect(Validation.isValidRelayURL("wss://relay.nostr.band/path"))
        
        // Invalid URLs
        #expect(!Validation.isValidRelayURL("https://example.com"))
        #expect(!Validation.isValidRelayURL("http://example.com"))
        #expect(!Validation.isValidRelayURL("not-a-url"))
        #expect(!Validation.isValidRelayURL(""))
        
        // Throws on invalid
        #expect(throws: NostrError.self) {
            try Validation.validateRelayURL("https://example.com")
        }
    }
    
    // MARK: - Event Validation Tests
    
    @Test("Complete event validation")
    func testCompleteEventValidation() throws {
        // Valid event
        let validEvent = NostrEvent(
            pubkey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            createdAt: Date(),
            kind: 1,
            tags: [["t", "nostr"]],
            content: "Hello, Nostr!"
        )
        
        try Validation.validateNostrEvent(validEvent)
        
        // Invalid pubkey
        let invalidPubkey = NostrEvent(
            pubkey: "invalid",
            createdAt: Date(),
            kind: 1,
            tags: [],
            content: "Test"
        )
        
        #expect(throws: NostrError.self) {
            try Validation.validateNostrEvent(invalidPubkey)
        }
        
        // Invalid timestamp (too far future)
        let futureEvent = NostrEvent(
            pubkey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            createdAt: Date().addingTimeInterval(3600), // 1 hour future
            kind: 1,
            tags: [],
            content: "Future"
        )
        
        #expect(throws: NostrError.self) {
            try Validation.validateNostrEvent(futureEvent)
        }
        
        // Content too large
        let largeContent = String(repeating: "x", count: 300 * 1024) // 300KB
        let largeEvent = NostrEvent(
            pubkey: "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            createdAt: Date(),
            kind: 1,
            tags: [],
            content: largeContent
        )
        
        #expect(throws: NostrError.self) {
            try Validation.validateNostrEvent(largeEvent)
        }
    }
    
    // MARK: - EventBuilder Tests
    
    @Test("EventBuilder text note creation")
    func testEventBuilderTextNote() throws {
        let keyPair = try KeyPair.generate()
        
        let event = try EventBuilder.text("Hello, Nostr!")
            .hashtag("nostr")
            .hashtag("test")
            .build(with: keyPair)
        
        #expect(event.kind == 1)
        #expect(event.content == "Hello, Nostr!")
        #expect(event.tags.contains { $0 == ["t", "nostr"] })
        #expect(event.tags.contains { $0 == ["t", "test"] })
        #expect(!event.sig.isEmpty)
        #expect(!event.id.isEmpty)
    }
    
    @Test("EventBuilder reply chain")
    func testEventBuilderReplyChain() throws {
        let keyPair = try KeyPair.generate()
        let rootId = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let replyId = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        let event = try EventBuilder.text("This is a reply")
            .root(rootId, relay: "wss://relay.example.com")
            .reply(to: replyId)
            .build(with: keyPair)
        
        #expect(event.kind == 1)
        #expect(event.tags.contains { tag in
            tag.count >= 4 && tag[0] == "e" && tag[1] == rootId && tag[3] == "root"
        })
        #expect(event.tags.contains { tag in
            tag.count >= 4 && tag[0] == "e" && tag[1] == replyId && tag[3] == "reply"
        })
    }
    
    @Test("EventBuilder metadata creation")
    func testEventBuilderMetadata() throws {
        let keyPair = try KeyPair.generate()
        
        let event = try EventBuilder.metadata(
            name: "Test User",
            about: "Testing Nostr",
            picture: "https://example.com/pic.jpg",
            nip05: "test@example.com"
        ).build(with: keyPair)
        
        #expect(event.kind == 0)
        
        let metadata = try JSONSerialization.jsonObject(with: Data(event.content.utf8)) as? [String: String]
        #expect(metadata?["name"] == "Test User")
        #expect(metadata?["about"] == "Testing Nostr")
        #expect(metadata?["picture"] == "https://example.com/pic.jpg")
        #expect(metadata?["nip05"] == "test@example.com")
    }
    
    @Test("EventBuilder article creation")
    func testEventBuilderArticle() throws {
        let keyPair = try KeyPair.generate()
        
        let event = try EventBuilder.article(
            identifier: "my-article",
            title: "Test Article",
            content: "# Article Content\n\nThis is the content.",
            summary: "A test article",
            image: "https://example.com/header.jpg"
        ).build(with: keyPair)
        
        #expect(event.kind == 30023)
        #expect(event.tags.contains { $0 == ["d", "my-article"] })
        #expect(event.tags.contains { $0 == ["title", "Test Article"] })
        #expect(event.tags.contains { $0 == ["summary", "A test article"] })
        #expect(event.tags.contains { $0 == ["image", "https://example.com/header.jpg"] })
    }
    
    @Test("EventBuilder validation during build")
    func testEventBuilderValidation() throws {
        let invalidPubkey = "not-valid"
        
        #expect(throws: NostrError.self) {
            _ = try EventBuilder.text("Test").buildUnsigned(pubkey: invalidPubkey)
        }
    }
    
    // MARK: - FilterBuilder Tests
    
    @Test("FilterBuilder basic usage")
    func testFilterBuilderBasic() {
        let filter = FilterBuilder()
            .kinds([1, 6, 7])
            .author("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
            .limit(50)
            .build()
        
        #expect(filter.kinds == [1, 6, 7])
        #expect(filter.authors == ["79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"])
        #expect(filter.limit == 50)
    }
    
    @Test("FilterBuilder time filtering")
    func testFilterBuilderTimeFiltering() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let filter = FilterBuilder()
            .between(yesterday, and: tomorrow)
            .build()
        
        #expect(filter.since == Int64(yesterday.timeIntervalSince1970))
        #expect(filter.until == Int64(tomorrow.timeIntervalSince1970))
        
        // Last hours helper
        let recentFilter = FilterBuilder()
            .lastHours(24)
            .build()
        
        #expect(recentFilter.since != nil)
        let timeDiff = Date().timeIntervalSince1970 - Double(recentFilter.since!)
        #expect(timeDiff < 86401 && timeDiff > 86399) // Allow 1 second tolerance
    }
    
    @Test("FilterBuilder convenience methods")
    func testFilterBuilderConvenience() {
        // Text notes filter
        let textFilter = FilterBuilder().textNotes().build()
        #expect(textFilter.kinds == [1])
        
        // Direct messages filter
        let dmFilter = FilterBuilder().directMessages().build()
        #expect(dmFilter.kinds == [4])
        
        // Articles filter
        let articleFilter = FilterBuilder().articles().build()
        #expect(articleFilter.kinds == [30023])
    }
    
    @Test("FilterBuilder static factories")
    func testFilterBuilderFactories() {
        let pubkey = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        
        // User posts
        let postsFilter = FilterBuilder.userPosts(pubkey).build()
        #expect(postsFilter.authors == [pubkey])
        #expect(postsFilter.kinds == [1, 6, 7])
        #expect(postsFilter.limit == 20)
        
        // User profile
        let profileFilter = FilterBuilder.userProfile(pubkey).build()
        #expect(profileFilter.authors == [pubkey])
        #expect(profileFilter.kinds == [0])
        #expect(profileFilter.limit == 1)
        
        // Replies
        let eventId = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        let repliesFilter = FilterBuilder.replies(to: eventId).build()
        #expect(repliesFilter.kinds == [1])
        #expect(repliesFilter.e == [eventId])
        #expect(repliesFilter.limit == 50)
        
        // Global feed
        let globalFilter = FilterBuilder.globalFeed().build()
        #expect(globalFilter.kinds == [1])
        #expect(globalFilter.limit == 100)
    }
    
    @Test("Filter fluent API extension")
    func testFilterFluentAPI() {
        let baseFilter = Filter(kinds: [1])
        
        let enhancedFilter = baseFilter.fluent
            .author("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
            .lastHours(1)
            .limit(10)
            .build()
        
        #expect(enhancedFilter.kinds == [1])
        #expect(enhancedFilter.authors?.count == 1)
        #expect(enhancedFilter.since != nil)
        #expect(enhancedFilter.limit == 10)
    }
    
    @Test("Filter build closure syntax")
    func testFilterBuildClosure() {
        let filter = Filter.build { builder in
            builder
                .textNotes()
                .lastDays(7)
                .limit(100)
        }
        
        #expect(filter.kinds == [1])
        #expect(filter.since != nil)
        #expect(filter.limit == 100)
    }
}