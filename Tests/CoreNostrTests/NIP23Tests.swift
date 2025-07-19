//
//  NIP23Tests.swift
//  CoreNostrTests
//
//  Created by Thomas Rademaker on 7/11/25.
//

import Testing
import Foundation
@testable import CoreNostr

@Suite("NIP-23: Long-form Content")
struct NIP23Tests {
    let keyPair: KeyPair
    
    init() throws {
        let privateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
        self.keyPair = try KeyPair(privateKey: privateKeyHex)
    }
    
    @Test("Create long-form content")
    func testCreateLongFormContent() {
        let article = LongFormContent(
            identifier: "my-first-article",
            title: "My First Article",
            content: "# Introduction\n\nThis is my first article on Nostr!",
            summary: "A brief introduction to my Nostr journey",
            image: "https://example.com/header.jpg",
            publishedAt: Date(timeIntervalSince1970: 1234567890),
            hashtags: ["nostr", "introduction", "blog"],
            isDraft: false
        )
        
        #expect(article.identifier == "my-first-article")
        #expect(article.title == "My First Article")
        #expect(article.content.contains("Introduction"))
        #expect(article.summary == "A brief introduction to my Nostr journey")
        #expect(article.image == "https://example.com/header.jpg")
        #expect(article.publishedAt?.timeIntervalSince1970 == 1234567890)
        #expect(article.hashtags.count == 3)
        #expect(!article.isDraft)
    }
    
    @Test("Create article event")
    func testCreateArticleEvent() throws {
        let event = try CoreNostr.createArticle(
            identifier: "test-article",
            title: "Test Article",
            content: "This is a test article with **markdown** support.",
            summary: "A test article",
            image: "https://example.com/test.jpg",
            hashtags: ["test", "markdown"],
            isDraft: false,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.longFormContent.rawValue)
        #expect(event.content == "This is a test article with **markdown** support.")
        
        let tags = event.tags
        #expect(tags.contains(["d", "test-article"]))
        #expect(tags.contains(["title", "Test Article"]))
        #expect(tags.contains(["summary", "A test article"]))
        #expect(tags.contains(["image", "https://example.com/test.jpg"]))
        #expect(tags.contains(["t", "test"]))
        #expect(tags.contains(["t", "markdown"]))
        
        // Should have published_at tag
        #expect(tags.contains { $0.count >= 2 && $0[0] == "published_at" })
    }
    
    @Test("Create draft event")
    func testCreateDraftEvent() throws {
        let event = try CoreNostr.createArticle(
            identifier: "draft-article",
            title: "Draft Article",
            content: "This is a work in progress...",
            isDraft: true,
            keyPair: keyPair
        )
        
        #expect(event.kind == EventKind.longFormDraft.rawValue)
        #expect(event.content == "This is a work in progress...")
        
        let tags = event.tags
        #expect(tags.contains(["d", "draft-article"]))
        #expect(tags.contains(["title", "Draft Article"]))
        
        // Drafts should not have published_at
        #expect(!tags.contains { $0.count >= 2 && $0[0] == "published_at" })
    }
    
    @Test("Parse long-form content from event")
    func testParseLongFormContent() throws {
        let originalArticle = LongFormContent(
            identifier: "parse-test",
            title: "Parse Test Article",
            content: "Content with references",
            summary: "Testing parsing",
            image: "https://example.com/parse.jpg",
            publishedAt: Date(timeIntervalSince1970: 1234567890),
            hashtags: ["parsing", "test"]
        )
        
        let event = try CoreNostr.createLongFormContent(originalArticle, keyPair: keyPair)
        
        #expect(event.isLongFormContent)
        #expect(!event.isLongFormDraft)
        #expect(event.isLongForm)
        
        let parsed = event.parseLongFormContent()
        #expect(parsed != nil)
        #expect(parsed?.identifier == "parse-test")
        #expect(parsed?.title == "Parse Test Article")
        #expect(parsed?.content == "Content with references")
        #expect(parsed?.summary == "Testing parsing")
        #expect(parsed?.image == "https://example.com/parse.jpg")
        #expect(parsed?.publishedAt?.timeIntervalSince1970 == 1234567890)
        #expect(parsed?.hashtags == ["parsing", "test"])
        #expect(parsed?.isDraft == false)
    }
    
    @Test("Article with Nostr references")
    func testArticleWithReferences() throws {
        // Use a valid nevent instead of note1 format
        let content = """
        Check out this event: nostr:nevent1qqsqhrasmmw0nnwjfeeka9sy4zl3c6rw5w2mtv4lugutl4luw57x7nqpr4mhxue69uhkummnw3ezucnfw33k76twv4ezuum0vd5kzmp0qyfhwumn8ghj7mmxve3ksctfdch8qatz9uq3wamnwvaz7tmjv4kxz7fwdehhxarj9e3xzmny9u76jrg5
        
        And this profile: nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6
        
        See also: nostr:naddr1qqzkjurnw4ksz9thwden5te0wfjkccte9ehx7um5wghx7un8qgs2d90kkcq3nk2jry62dyf50k0h36rhpdtd594my40w9pkal876jxgrqsqqqa28pccpzu
        """
        
        let article = LongFormContent(
            identifier: "ref-article",
            title: "Article with References",
            content: content
            // Don't pass references - they will be automatically parsed from content
        )
        
        let event = try CoreNostr.createLongFormContent(article, keyPair: keyPair)
        
        // Should create reference tags
        let eTags = event.tags.filter { $0.count >= 2 && $0[0] == "e" }
        let pTags = event.tags.filter { $0.count >= 2 && $0[0] == "p" }
        let aTags = event.tags.filter { $0.count >= 2 && $0[0] == "a" }
        
        #expect(eTags.count == 1)
        #expect(pTags.count == 1)
        #expect(aTags.count == 1)
    }
    
    @Test("Update article")
    func testUpdateArticle() throws {
        let originalPublished = Date(timeIntervalSince1970: 1234567890)
        
        let updatedEvent = try CoreNostr.updateArticle(
            identifier: "my-article",
            title: "My Updated Article",
            content: "Updated content with new information",
            summary: "Now with more details",
            originalPublishedAt: originalPublished,
            keyPair: keyPair
        )
        
        #expect(updatedEvent.kind == EventKind.longFormContent.rawValue)
        
        let tags = updatedEvent.tags
        #expect(tags.contains(["d", "my-article"]))
        #expect(tags.contains(["title", "My Updated Article"]))
        #expect(tags.contains(["summary", "Now with more details"]))
        
        // Should preserve original published_at
        #expect(tags.contains(["published_at", "1234567890"]))
    }
    
    @Test("Publish draft")
    func testPublishDraft() throws {
        let draft = LongFormContent(
            identifier: "draft-to-publish",
            title: "Ready to Publish",
            content: "This draft is now complete!",
            isDraft: true
        )
        
        let publishedEvent = try CoreNostr.publishDraft(draft, keyPair: keyPair)
        
        #expect(publishedEvent.kind == EventKind.longFormContent.rawValue)
        #expect(!publishedEvent.isLongFormDraft)
        #expect(publishedEvent.isLongFormContent)
        
        // Should have published_at tag
        let tags = publishedEvent.tags
        #expect(tags.contains { $0.count >= 2 && $0[0] == "published_at" })
    }
    
    @Test("Article metadata")
    func testArticleMetadata() throws {
        let article = LongFormContent(
            identifier: "metadata-test",
            title: "Metadata Test",
            content: "Testing metadata extraction",
            summary: "Metadata summary",
            image: "https://example.com/meta.jpg",
            publishedAt: Date(timeIntervalSince1970: 1234567890),
            hashtags: ["meta", "test"]
        )
        
        let event = try CoreNostr.createLongFormContent(article, keyPair: keyPair)
        
        let metadata = event.getArticleMetadata()
        #expect(metadata != nil)
        #expect(metadata?.identifier == "metadata-test")
        #expect(metadata?.title == "Metadata Test")
        #expect(metadata?.summary == "Metadata summary")
        #expect(metadata?.image == "https://example.com/meta.jpg")
        #expect(metadata?.publishedAt?.timeIntervalSince1970 == 1234567890)
        #expect(metadata?.author == keyPair.publicKey)
        #expect(metadata?.hashtags == ["meta", "test"])
    }
    
    @Test("Long-form content filter")
    func testLongFormContentFilter() {
        let filter = Filter.longFormContent(
            authors: ["author1", "author2"],
            hashtags: ["nostr", "blog"],
            since: Date(timeIntervalSince1970: 1000000),
            until: Date(timeIntervalSince1970: 2000000),
            limit: 50,
            includeDrafts: true
        )
        
        #expect(filter.kinds?.contains(EventKind.longFormContent.rawValue) == true)
        #expect(filter.kinds?.contains(EventKind.longFormDraft.rawValue) == true)
        #expect(filter.authors == ["author1", "author2"])
        #expect(filter.since == 1000000)
        #expect(filter.until == 2000000)
        #expect(filter.limit == 50)
    }
    
    @Test("Article discovery helpers")
    func testArticleDiscoveryHelpers() {
        // By hashtag
        let hashtagFilter = ArticleDiscovery.byHashtag("nostr", limit: 10)
        #expect(hashtagFilter.kinds == [EventKind.longFormContent.rawValue])
        #expect(hashtagFilter.limit == 10)
        
        // By author
        let authorFilter = ArticleDiscovery.byAuthor("pubkey123", includeDrafts: true, limit: 30)
        #expect(authorFilter.authors == ["pubkey123"])
        #expect(authorFilter.kinds?.contains(EventKind.longFormContent.rawValue) == true)
        #expect(authorFilter.kinds?.contains(EventKind.longFormDraft.rawValue) == true)
        #expect(authorFilter.limit == 30)
        
        // Recent articles
        let recentFilter = ArticleDiscovery.recent(limit: 100)
        #expect(recentFilter.kinds == [EventKind.longFormContent.rawValue])
        #expect(recentFilter.limit == 100)
    }
    
    @Test("Custom tags preservation")
    func testCustomTagsPreservation() throws {
        let customTags = [
            ["custom", "value1"],
            ["another", "value2", "value3"]
        ]
        
        let article = LongFormContent(
            identifier: "custom-tags",
            title: "Custom Tags Article",
            content: "Article with custom tags",
            customTags: customTags
        )
        
        let event = try CoreNostr.createLongFormContent(article, keyPair: keyPair)
        
        // Custom tags should be preserved
        #expect(event.tags.contains(["custom", "value1"]))
        #expect(event.tags.contains(["another", "value2", "value3"]))
        
        // Parse back and check custom tags
        let parsed = event.parseLongFormContent()
        #expect(parsed?.customTags.contains(["custom", "value1"]) == true)
        #expect(parsed?.customTags.contains(["another", "value2", "value3"]) == true)
    }
    
    @Test("Invalid event parsing")
    func testInvalidEventParsing() {
        // Wrong event kind
        let wrongKindEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Not an article"
        )
        
        #expect(wrongKindEvent.parseLongFormContent() == nil)
        #expect(!wrongKindEvent.isLongForm)
        
        // Missing required tags
        let missingTagsEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            kind: EventKind.longFormContent.rawValue,
            tags: [["d", "identifier"]], // Missing title
            content: "Content"
        )
        
        #expect(missingTagsEvent.parseLongFormContent() == nil)
    }
    
    @Test("Hashtag handling")
    func testHashtagHandling() throws {
        // Test hashtags with and without # prefix
        let article = LongFormContent(
            identifier: "hashtag-test",
            title: "Hashtag Test",
            content: "Testing hashtags",
            hashtags: ["#nostr", "bitcoin", "#lightning"]
        )
        
        let event = try CoreNostr.createLongFormContent(article, keyPair: keyPair)
        
        // All hashtags should be stored without # prefix
        let tTags = event.tags.filter { $0.count >= 2 && $0[0] == "t" }.map { $0[1] }
        #expect(tTags.contains("nostr"))
        #expect(tTags.contains("bitcoin"))
        #expect(tTags.contains("lightning"))
        #expect(!tTags.contains("#nostr"))
        #expect(!tTags.contains("#lightning"))
    }
}