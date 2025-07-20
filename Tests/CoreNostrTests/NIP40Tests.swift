//
//  NIP40Tests.swift
//  CoreNostrTests
//
//  Tests for NIP-40: Expiration Timestamp
//

import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-40: Expiration Timestamp")
struct NIP40Tests {
    
    @Test("Create expiration tag with timestamp")
    func createExpirationTagTimestamp() throws {
        let timestamp: Int64 = 1700000000
        let tag = NIP40.expirationTag(at: timestamp)
        
        #expect(tag.count == 2)
        #expect(tag[0] == "expiration")
        #expect(tag[1] == "1700000000")
    }
    
    @Test("Create expiration tag with date")
    func createExpirationTagDate() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let tag = NIP40.expirationTag(at: date)
        
        #expect(tag.count == 2)
        #expect(tag[0] == "expiration")
        #expect(tag[1] == "1700000000")
    }
    
    @Test("Create expiration tag with interval")
    func createExpirationTagInterval() throws {
        let now = Date()
        let tag = NIP40.expirationTag(after: .hours(24))
        
        #expect(tag.count == 2)
        #expect(tag[0] == "expiration")
        
        let timestamp = Int64(tag[1]) ?? 0
        let expectedTimestamp = Int64(now.timeIntervalSince1970) + 86400
        
        // Allow 5 second tolerance for test execution time
        #expect(abs(timestamp - expectedTimestamp) < 5)
    }
    
    @Test("Expiration interval conversions")
    func expirationIntervalConversions() throws {
        #expect(NIP40.ExpirationInterval.seconds(60).timeInterval == 60)
        #expect(NIP40.ExpirationInterval.minutes(5).timeInterval == 300)
        #expect(NIP40.ExpirationInterval.hours(2).timeInterval == 7200)
        #expect(NIP40.ExpirationInterval.days(1).timeInterval == 86400)
        #expect(NIP40.ExpirationInterval.custom(123.45).timeInterval == 123.45)
    }
    
    @Test("Extract expiration from event")
    func extractExpiration() throws {
        let event = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["expiration", "1700000000"], ["p", "someone"]],
            content: "Test message"
        )
        
        let timestamp = NIP40.expirationTimestamp(from: event)
        #expect(timestamp == 1700000000)
        
        let date = NIP40.expirationDate(from: event)
        #expect(date == Date(timeIntervalSince1970: 1700000000))
    }
    
    @Test("Event without expiration")
    func eventWithoutExpiration() throws {
        let event = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["p", "someone"]],
            content: "Test message"
        )
        
        #expect(NIP40.expirationTimestamp(from: event) == nil)
        #expect(NIP40.expirationDate(from: event) == nil)
        #expect(NIP40.isExpired(event) == false)
    }
    
    @Test("Check expired event")
    func checkExpiredEvent() throws {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        
        let expiredEvent = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["expiration", String(Int64(pastDate.timeIntervalSince1970))]],
            content: "Expired message"
        )
        
        let activeEvent = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["expiration", String(Int64(futureDate.timeIntervalSince1970))]],
            content: "Active message"
        )
        
        #expect(NIP40.isExpired(expiredEvent) == true)
        #expect(NIP40.isExpired(activeEvent) == false)
    }
    
    @Test("Check expires within interval")
    func expiresWithinInterval() throws {
        let in30Minutes = Date().addingTimeInterval(1800)
        let in2Hours = Date().addingTimeInterval(7200)
        
        let event1 = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["expiration", String(Int64(in30Minutes.timeIntervalSince1970))]],
            content: "Expires in 30 minutes"
        )
        
        let event2 = NostrEvent(
            pubkey: "test-pubkey",
            createdAt: Date(),
            kind: 1,
            tags: [["expiration", String(Int64(in2Hours.timeIntervalSince1970))]],
            content: "Expires in 2 hours"
        )
        
        #expect(NIP40.expiresWithin(event1, interval: .hours(1)) == true)
        #expect(NIP40.expiresWithin(event2, interval: .hours(1)) == false)
        #expect(NIP40.expiresWithin(event2, interval: .hours(3)) == true)
    }
    
    @Test("Filter expired events")
    func filterExpiredEvents() throws {
        let past = Date().addingTimeInterval(-3600)
        let future = Date().addingTimeInterval(3600)
        
        let events = [
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [["expiration", String(Int64(past.timeIntervalSince1970))]],
                content: "Expired"
            ),
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [["expiration", String(Int64(future.timeIntervalSince1970))]],
                content: "Active"
            ),
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [],
                content: "No expiration"
            )
        ]
        
        let filtered = NIP40.filterExpired(events)
        #expect(filtered.count == 2)
        #expect(filtered[0].content == "Active")
        #expect(filtered[1].content == "No expiration")
    }
    
    @Test("Sort by expiration")
    func sortByExpiration() throws {
        let time1 = Date().addingTimeInterval(3600)
        let time2 = Date().addingTimeInterval(7200)
        let time3 = Date().addingTimeInterval(10800)
        
        let events = [
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [["expiration", String(Int64(time3.timeIntervalSince1970))]],
                content: "Third"
            ),
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [],
                content: "No expiration"
            ),
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [["expiration", String(Int64(time1.timeIntervalSince1970))]],
                content: "First"
            ),
            NostrEvent(
                pubkey: "test",
                kind: 1,
                tags: [["expiration", String(Int64(time2.timeIntervalSince1970))]],
                content: "Second"
            )
        ]
        
        let sorted = NIP40.sortByExpiration(events)
        #expect(sorted[0].content == "First")
        #expect(sorted[1].content == "Second")
        #expect(sorted[2].content == "Third")
        #expect(sorted[3].content == "No expiration")
    }
    
    @Test("NostrEvent extensions")
    func nostrEventExtensions() throws {
        let keyPair = try KeyPair.generate()
        let originalEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: 1,
            tags: [["p", "someone"]],
            content: "Test message"
        )
        
        // Add expiration
        let expiringEvent = originalEvent.withExpiration(after: .hours(24))
        
        #expect(originalEvent.expirationTimestamp == nil)
        #expect(originalEvent.isExpired == false)
        
        #expect(expiringEvent.expirationTimestamp != nil)
        #expect(expiringEvent.isExpired == false)
        
        // Check the expiration is roughly 24 hours from now
        let expectedExpiration = Date().addingTimeInterval(86400).timeIntervalSince1970
        let actualExpiration = TimeInterval(expiringEvent.expirationTimestamp ?? 0)
        #expect(abs(actualExpiration - expectedExpiration) < 5)
    }
    
    @Test("Replace existing expiration tag")
    func replaceExpirationTag() throws {
        let event = NostrEvent(
            pubkey: "test",
            kind: 1,
            tags: [["expiration", "1000000"], ["p", "someone"]],
            content: "Test"
        )
        
        let updated = event.withExpiration(after: .hours(1))
        
        let expirationTags = updated.tags.filter { $0.count >= 1 && $0[0] == "expiration" }
        #expect(expirationTags.count == 1)
        #expect(updated.tags.contains { $0.count >= 2 && $0[0] == "p" && $0[1] == "someone" })
    }
    
    @Test("Tag name constant")
    func tagNameConstant() throws {
        #expect(NIP40.tagName == "expiration")
    }
}