import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-09: Event Deletion Tests")
struct NIP09Tests {
    
    let keyPair = try! KeyPair.generate()
    let otherKeyPair = try! KeyPair.generate()
    
    @Test("Create deletion event for single event")
    func testCreateSingleDeletionEvent() throws {
        let eventId = "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7"
        let reason = "Posted by mistake"
        
        let deletionEvent = try CoreNostr.createDeletionEvent(
            for: eventId,
            reason: reason,
            keyPair: keyPair
        )
        
        #expect(deletionEvent.kind == EventKind.deletion.rawValue)
        #expect(deletionEvent.pubkey == keyPair.publicKey)
        #expect(deletionEvent.content == reason)
        
        // Check tags
        let eTags = deletionEvent.tags.filter { $0.first == "e" }
        let reasonTags = deletionEvent.tags.filter { $0.first == "reason" }
        
        #expect(eTags.count == 1)
        #expect(eTags[0] == ["e", eventId])
        
        #expect(reasonTags.count == 1)
        #expect(reasonTags[0] == ["reason", reason])
        
        // Verify signature
        #expect(try CoreNostr.verifyEvent(deletionEvent))
    }
    
    @Test("Create deletion event for multiple events")
    func testCreateMultipleDeletionEvent() throws {
        let eventIds = [
            "d1b3f0c8a2e5d7f9b1c3e5a7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7",
            "a2c4e6f8b0d2e4f6a8c0e2f4b6d8e0f2c4e6f8a0c2e4f6b8d0e2f4c6e8f0a2c4",
            "b3d5f7a9c1e3f5b7d9f1b3c5e7a9d1f3b5c7e9a1d3f5b7c9e1a3d5f7b9d1c3e5"
        ]
        
        let deletionEvent = try CoreNostr.createDeletionEvent(
            eventIds: eventIds,
            reason: nil,
            keyPair: keyPair
        )
        
        #expect(deletionEvent.kind == EventKind.deletion.rawValue)
        #expect(deletionEvent.content == "") // No reason provided
        
        // Check e tags
        let eTags = deletionEvent.tags.filter { $0.first == "e" }
        #expect(eTags.count == 3)
        #expect(eTags.map { $0[1] }.sorted() == eventIds.sorted())
        
        // No reason tag when reason is nil
        let reasonTags = deletionEvent.tags.filter { $0.first == "reason" }
        #expect(reasonTags.isEmpty)
    }
    
    @Test("Deletion event properties")
    func testDeletionEventProperties() throws {
        let eventIds = ["event1", "event2", "event3"]
        let reason = "Cleaning up old posts"
        
        let deletionEvent = try CoreNostr.createDeletionEvent(
            eventIds: eventIds,
            reason: reason,
            keyPair: keyPair
        )
        
        #expect(deletionEvent.isDeletionEvent)
        #expect(deletionEvent.deletedEventIds.sorted() == eventIds.sorted())
        #expect(deletionEvent.deletionReason == reason)
        
        // Test deletion info
        let (isDeleted1, reason1) = deletionEvent.deletionInfo(for: "event1")
        #expect(isDeleted1)
        #expect(reason1 == reason)
        
        let (isDeleted4, reason4) = deletionEvent.deletionInfo(for: "event4")
        #expect(!isDeleted4)
        #expect(reason4 == nil)
    }
    
    @Test("Non-deletion event properties")
    func testNonDeletionEventProperties() throws {
        // Create a regular text note
        let textEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [["e", "someevent"], ["p", "somepubkey"]],
            content: "Just a regular note"
        )
        let signedEvent = try keyPair.signEvent(textEvent)
        
        #expect(!signedEvent.isDeletionEvent)
        #expect(signedEvent.deletedEventIds.isEmpty)
        #expect(signedEvent.deletionReason == nil)
        
        let (isDeleted, reason) = signedEvent.deletionInfo(for: "anyevent")
        #expect(!isDeleted)
        #expect(reason == nil)
    }
    
    @Test("Empty event IDs throws error")
    func testEmptyEventIdsThrows() throws {
        #expect(throws: NostrError.self) {
            _ = try CoreNostr.createDeletionEvent(
                eventIds: [],
                reason: "No events",
                keyPair: keyPair
            )
        }
    }
    
    @Test("Filter for deletion events")
    func testDeletionEventFilters() {
        // Filter for all deletion events
        let allDeletions = Filter.deletionEvents()
        #expect(allDeletions.kinds == [EventKind.deletion.rawValue])
        #expect(allDeletions.authors == nil)
        #expect(allDeletions.e == nil)
        
        // Filter for deletions by specific authors
        let authorDeletions = Filter.deletionEvents(
            authors: [keyPair.publicKey, otherKeyPair.publicKey]
        )
        #expect(authorDeletions.kinds == [EventKind.deletion.rawValue])
        #expect(authorDeletions.authors == [keyPair.publicKey, otherKeyPair.publicKey])
        
        // Filter for deletions of specific events
        let specificDeletions = Filter.deletionsOf(eventIds: ["event1", "event2"])
        #expect(specificDeletions.kinds == [EventKind.deletion.rawValue])
        #expect(specificDeletions.e == ["event1", "event2"])
    }
    
    @Test("DeletionTracker functionality")
    func testDeletionTracker() throws {
        var tracker = DeletionTracker()
        
        // Create some deletion events
        let deletion1 = try CoreNostr.createDeletionEvent(
            eventIds: ["event1", "event2"],
            reason: "Spam",
            keyPair: keyPair
        )
        
        let deletion2 = try CoreNostr.createDeletionEvent(
            eventIds: ["event3"],
            reason: "Outdated",
            keyPair: otherKeyPair
        )
        
        // Process deletion events
        tracker.processDeletionEvent(deletion1)
        tracker.processDeletionEvent(deletion2)
        
        // Check deletion status
        #expect(tracker.isDeleted("event1"))
        #expect(tracker.isDeleted("event2"))
        #expect(tracker.isDeleted("event3"))
        #expect(!tracker.isDeleted("event4"))
        
        // Check deletion info
        let info1 = tracker.deletionInfo(for: "event1")
        #expect(info1?.reason == "Spam")
        #expect(info1?.authorPubkey == keyPair.publicKey)
        #expect(info1?.deletionEventId == deletion1.id)
        
        let info3 = tracker.deletionInfo(for: "event3")
        #expect(info3?.reason == "Outdated")
        #expect(info3?.authorPubkey == otherKeyPair.publicKey)
        
        // Test untracking
        tracker.untrack("event1")
        #expect(!tracker.isDeleted("event1"))
        #expect(tracker.isDeleted("event2"))
        
        // Test clear
        tracker.clear()
        #expect(!tracker.isDeleted("event2"))
        #expect(!tracker.isDeleted("event3"))
    }
    
    @Test("DeletionTracker ignores non-deletion events")
    func testDeletionTrackerIgnoresNonDeletions() throws {
        var tracker = DeletionTracker()
        
        // Create a regular event
        let textEvent = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [["e", "someevent"]],
            content: "Not a deletion"
        )
        let signedEvent = try keyPair.signEvent(textEvent)
        
        // Process non-deletion event
        tracker.processDeletionEvent(signedEvent)
        
        // Should not track anything
        #expect(!tracker.isDeleted("someevent"))
        #expect(tracker.deletionInfo(for: "someevent") == nil)
    }
    
    @Test("Complex deletion scenario")
    func testComplexDeletionScenario() throws {
        // Create original events
        let event1 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "First post"
        )
        let signedEvent1 = try keyPair.signEvent(event1)
        
        let event2 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Second post"
        )
        let signedEvent2 = try keyPair.signEvent(event2)
        
        // Create deletion event
        let deletion = try CoreNostr.createDeletionEvent(
            eventIds: [signedEvent1.id, signedEvent2.id],
            reason: "Starting fresh",
            keyPair: keyPair
        )
        
        // Verify deletion references the correct events
        #expect(deletion.deletedEventIds.contains(signedEvent1.id))
        #expect(deletion.deletedEventIds.contains(signedEvent2.id))
        #expect(deletion.deletionReason == "Starting fresh")
        
        // Track deletions
        var tracker = DeletionTracker()
        tracker.processDeletionEvent(deletion)
        
        #expect(tracker.isDeleted(signedEvent1.id))
        #expect(tracker.isDeleted(signedEvent2.id))
        
        let info = tracker.deletionInfo(for: signedEvent1.id)
        #expect(info?.deletionEventId == deletion.id)
        #expect(info?.reason == "Starting fresh")
    }
    
    @Test("EventKind deletion constant")
    func testEventKindDeletion() {
        #expect(EventKind.deletion.rawValue == 5)
    }
}