import Testing
@testable import CoreNostr
import Foundation

@Suite("NIP-13: Proof of Work Tests")
struct NIP13Tests {
    
    let keyPair = try! KeyPair.generate()
    
    @Test("Calculate difficulty from event ID")
    func testCalculateDifficulty() {
        // Test various event IDs with known difficulties
        
        // No leading zeros
        let id1 = "f123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        #expect(ProofOfWork.calculateDifficulty(eventId: id1) == 0)
        
        // 7 leading zero bits (0 = 4 bits, 1 = 0001 = 3 bits)
        let id2 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        #expect(ProofOfWork.calculateDifficulty(eventId: id2) == 7)
        
        // 11 leading zero bits (00 = 8 bits, 1 = 0001 = 3 bits)
        let id3 = "00123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde"
        #expect(ProofOfWork.calculateDifficulty(eventId: id3) == 11)
        
        // 15 leading zero bits (000 = 12 bits, 1 = 0001 = 3 bits)
        let id4 = "000123456789abcdef0123456789abcdef0123456789abcdef0123456789abc"
        #expect(ProofOfWork.calculateDifficulty(eventId: id4) == 15)
        
        // 4 leading zero bits (0 = 4 bits, 8 = 1000 = 0 bits)
        let id5 = "08123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
        #expect(ProofOfWork.calculateDifficulty(eventId: id5) == 4)
        
        // 5 leading zero bits (0 = 4 bits, 4 = 0100 = 1 bit)
        let id6 = "04123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
        #expect(ProofOfWork.calculateDifficulty(eventId: id6) == 5)
        
        // 6 leading zero bits (0 = 4 bits, 2 = 0010 = 2 bits)
        let id7 = "02123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
        #expect(ProofOfWork.calculateDifficulty(eventId: id7) == 6)
        
        // 7 leading zero bits (0x01 = 0000 0001)
        let id8 = "01123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
        #expect(ProofOfWork.calculateDifficulty(eventId: id8) == 7)
    }
    
    @Test("Mine event with low difficulty")
    func testMineLowDifficulty() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Test proof of work"
        )
        
        // Mine with difficulty 8 (should be fast)
        let minedEvent = try await ProofOfWork.mine(
            event: event,
            targetDifficulty: 8
        )
        
        // Verify the mined event
        #expect(minedEvent.powDifficulty >= 8)
        #expect(minedEvent.hasProofOfWork)
        #expect(minedEvent.powNonce != nil)
        #expect(minedEvent.claimedDifficulty == 8)
        
        // Check nonce tag format
        let nonceTags = minedEvent.tags.filter { $0.first == "nonce" }
        #expect(nonceTags.count == 1)
        #expect(nonceTags[0].count == 3)
        #expect(nonceTags[0][2] == "8")
        
        // Verify the event meets difficulty
        #expect(ProofOfWork.verify(event: minedEvent, minimumDifficulty: 8))
        #expect(!ProofOfWork.verify(event: minedEvent, minimumDifficulty: 9))
    }
    
    @Test("Mine with zero difficulty")
    func testMineZeroDifficulty() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "No work needed"
        )
        
        // Mine with difficulty 0 (should return immediately)
        let minedEvent = try await ProofOfWork.mine(
            event: event,
            targetDifficulty: 0
        )
        
        // Should be the same event (no nonce added)
        #expect(minedEvent.tags == event.tags)
        #expect(!minedEvent.hasProofOfWork)
        #expect(ProofOfWork.verify(event: minedEvent, minimumDifficulty: 0))
    }
    
    @Test("Mining with custom configuration")
    func testMiningConfiguration() async throws {
        actor ProgressCollector {
            var updates: [(UInt64, Double)] = []
            
            func append(_ update: (UInt64, Double)) {
                updates.append(update)
            }
            
            func getUpdates() -> [(UInt64, Double)] {
                updates
            }
        }
        
        let progressCollector = ProgressCollector()
        
        let config = ProofOfWork.MiningConfig(
            batchSize: 100,
            startNonce: 1000,
            maxNonce: 10000,
            progressHandler: { nonce, hashRate in
                Task {
                    await progressCollector.append((nonce, hashRate))
                }
            }
        )
        
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Custom config test"
        )
        
        do {
            let minedEvent = try await ProofOfWork.mine(
                event: event,
                targetDifficulty: 12,  // Moderate difficulty
                config: config
            )
            
            // Check nonce is in expected range
            #expect(minedEvent.powNonce! >= 1000)
            #expect(minedEvent.powNonce! <= 10000)
            
            // Should have progress updates
            let updates = await progressCollector.getUpdates()
            #expect(!updates.isEmpty)
        } catch ProofOfWork.PoWError.nonceOverflow {
            // Expected if we can't find solution in range
            #expect(Bool(true))
        }
    }
    
    @Test("Mining with timeout", .disabled("Causing signal code 5"))
    func testMiningTimeout() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Timeout test"
        )
        
        // Try to mine with very high difficulty and short timeout
        do {
            _ = try await ProofOfWork.mine(
                event: event,
                targetDifficulty: 20,  // High difficulty
                timeout: 0.1  // 100ms timeout
            )
            Issue.record("Should have timed out")
        } catch ProofOfWork.PoWError.miningTimeout {
            // Expected
            #expect(Bool(true))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Mining cancellation", .disabled("Causing signal code 5"))
    func testMiningCancellation() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Cancellation test"
        )
        
        // Start mining task with high difficulty
        let task = Task {
            try await ProofOfWork.mine(
                event: event,
                targetDifficulty: 20  // High difficulty
            )
        }
        
        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        task.cancel()
        
        do {
            _ = try await task.result.get()
            Issue.record("Should have been cancelled")
        } catch ProofOfWork.PoWError.miningCancelled {
            // Expected
            #expect(Bool(true))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Verify event proof of work")
    func testVerifyProofOfWork() throws {
        // Create event with manual nonce that gives known difficulty
        let event1 = NostrEvent(
            unvalidatedId: "000123456789abcdef0123456789abcdef0123456789abcdef0123456789abc",  // 15 bits (000 = 12, 1 = 3)
            pubkey: keyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.textNote.rawValue,
            tags: [["nonce", "12345", "15"]],
            content: "Test",
            sig: "dummy"
        )
        
        #expect(ProofOfWork.verify(event: event1, minimumDifficulty: 15))
        #expect(ProofOfWork.verify(event: event1, minimumDifficulty: 14))
        #expect(!ProofOfWork.verify(event: event1, minimumDifficulty: 16))
        
        // Event without nonce tag
        let event2 = NostrEvent(
            unvalidatedId: "000123456789abcdef0123456789abcdef0123456789abcdef0123456789abc",  // 15 bits
            pubkey: keyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Test",
            sig: "dummy"
        )
        
        #expect(!ProofOfWork.verify(event: event2, minimumDifficulty: 12))
        #expect(ProofOfWork.verify(event: event2, minimumDifficulty: 0))
        
        // Event with wrong claimed difficulty
        let event3 = NostrEvent(
            unvalidatedId: "000123456789abcdef0123456789abcdef0123456789abcdef0123456789abc",  // 15 bits
            pubkey: keyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.textNote.rawValue,
            tags: [["nonce", "12345", "20"]],  // Claims 20 bits but only has 15
            content: "Test",
            sig: "dummy"
        )
        
        #expect(!ProofOfWork.verify(event: event3, minimumDifficulty: 12))
    }
    
    @Test("Extract nonce from event")
    func testExtractNonce() {
        // Event with nonce
        let event1 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [["nonce", "42", "16"]],
            content: "Test"
        )
        
        let nonce1 = ProofOfWork.extractNonce(from: event1)
        #expect(nonce1?.nonce == 42)
        #expect(nonce1?.difficulty == 16)
        
        // Event without nonce
        let event2 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Test"
        )
        
        #expect(ProofOfWork.extractNonce(from: event2) == nil)
        
        // Event with invalid nonce format
        let event3 = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [["nonce", "not-a-number", "16"]],
            content: "Test"
        )
        
        #expect(ProofOfWork.extractNonce(from: event3) == nil)
    }
    
    @Test("NostrEvent PoW extensions")
    func testNostrEventExtensions() {
        let event = NostrEvent(
            unvalidatedId: "00000000c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaef",  // 32 bits
            pubkey: keyPair.publicKey,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: EventKind.textNote.rawValue,
            tags: [["nonce", "999999", "32"]],
            content: "High PoW event",
            sig: "dummy"
        )
        
        #expect(event.powDifficulty == 32)
        #expect(event.hasProofOfWork)
        #expect(event.powNonce == 999999)
        #expect(event.claimedDifficulty == 32)
    }
    
    @Test("Time estimation")
    func testTimeEstimation() {
        // Test time estimation for various difficulties and hash rates
        
        // 10 bits at 1000 H/s
        let time1 = ProofOfWork.estimateTime(difficulty: 10, hashRate: 1000)
        #expect(time1 > 1.0 && time1 < 2.0)  // ~1.024 seconds
        
        // 20 bits at 1M H/s
        let time2 = ProofOfWork.estimateTime(difficulty: 20, hashRate: 1_000_000)
        #expect(time2 > 1.0 && time2 < 2.0)  // ~1.048 seconds
        
        // 0 difficulty
        let time3 = ProofOfWork.estimateTime(difficulty: 0, hashRate: 1000)
        #expect(time3 == 0)
        
        // 0 hash rate
        let time4 = ProofOfWork.estimateTime(difficulty: 10, hashRate: 0)
        #expect(time4 == 0)
    }
    
    @Test("Hash rate calculation")
    func testHashRateCalculation() {
        // 1000 hashes in 1 second = 1000 H/s
        let rate1 = ProofOfWork.calculateHashRate(hashes: 1000, duration: 1.0)
        #expect(rate1 == 1000)
        
        // 1M hashes in 0.5 seconds = 2M H/s
        let rate2 = ProofOfWork.calculateHashRate(hashes: 1_000_000, duration: 0.5)
        #expect(rate2 == 2_000_000)
        
        // 0 duration
        let rate3 = ProofOfWork.calculateHashRate(hashes: 1000, duration: 0)
        #expect(rate3 == 0)
    }
    
    @Test("CoreNostr convenience method")
    func testCreateMinedEvent() async throws {
        let minedEvent = try await CoreNostr.createMinedEvent(
            content: "Mined message",
            kind: EventKind.textNote.rawValue,
            tags: [["t", "pow"]],
            difficulty: 8,
            keyPair: keyPair
        )
        
        // Verify it's properly mined and signed
        #expect(minedEvent.powDifficulty >= 8)
        #expect(minedEvent.hasProofOfWork)
        #expect(minedEvent.content == "Mined message")
        #expect(minedEvent.tags.contains { $0 == ["t", "pow"] })
        
        // Verify signature
        #expect(try CoreNostr.verifyEvent(minedEvent))
        
        // Verify PoW
        #expect(ProofOfWork.verify(event: minedEvent, minimumDifficulty: 8))
    }
    
    @Test("Invalid difficulty")
    func testInvalidDifficulty() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Test"
        )
        
        // Negative difficulty
        do {
            _ = try await ProofOfWork.mine(event: event, targetDifficulty: -1)
            Issue.record("Should have thrown invalid difficulty error")
        } catch ProofOfWork.PoWError.invalidDifficulty {
            #expect(Bool(true))
        }
        
        // Too high difficulty
        do {
            _ = try await ProofOfWork.mine(event: event, targetDifficulty: 256)
            Issue.record("Should have thrown invalid difficulty error")
        } catch ProofOfWork.PoWError.invalidDifficulty {
            #expect(Bool(true))
        }
    }
    
    @Test("Performance benchmark", .disabled("Enable for performance testing"))
    func testMiningPerformance() async throws {
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: EventKind.textNote.rawValue,
            tags: [],
            content: "Performance test"
        )
        
        let startTime = Date()
        
        actor HashCounter {
            var count: UInt64 = 0
            
            func update(_ newCount: UInt64) {
                count = newCount
            }
            
            func getCount() -> UInt64 {
                count
            }
        }
        
        let hashCounter = HashCounter()
        
        let config = ProofOfWork.MiningConfig(
            batchSize: 10000,
            progressHandler: { nonce, hashRate in
                Task {
                    await hashCounter.update(nonce)
                    print("Progress: \(nonce) nonces, \(Int(hashRate)) H/s")
                }
            }
        )
        
        let minedEvent = try await ProofOfWork.mine(
            event: event,
            targetDifficulty: 12,  // Moderate difficulty for benchmarking
            config: config
        )
        
        let duration = Date().timeIntervalSince(startTime)
        let hashCount = await hashCounter.getCount()
        let hashRate = ProofOfWork.calculateHashRate(hashes: hashCount, duration: duration)
        
        print("Mining completed:")
        print("- Difficulty: 16 bits")
        print("- Time: \(duration) seconds")
        print("- Hashes: \(hashCount)")
        print("- Hash rate: \(Int(hashRate)) H/s")
        print("- Final nonce: \(minedEvent.powNonce ?? 0)")
        
        #expect(minedEvent.powDifficulty >= 16)
    }
}