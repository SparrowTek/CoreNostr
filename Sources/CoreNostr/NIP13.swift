import Foundation
import CryptoKit

/// NIP-13: Proof of Work
/// https://github.com/nostr-protocol/nips/blob/master/13.md
///
/// Proof of Work for Nostr events to prevent spam by requiring computational work

public struct ProofOfWork {
    
    /// Error types for Proof of Work operations
    public enum PoWError: Error, LocalizedError {
        case invalidDifficulty
        case miningCancelled
        case miningTimeout
        case nonceOverflow
        
        public var errorDescription: String? {
            switch self {
            case .invalidDifficulty:
                return "Invalid difficulty target"
            case .miningCancelled:
                return "Mining operation was cancelled"
            case .miningTimeout:
                return "Mining operation timed out"
            case .nonceOverflow:
                return "Nonce value overflowed"
            }
        }
    }
    
    /// Configuration for mining operations
    public struct MiningConfig: Sendable {
        /// Number of hashes to compute before checking for cancellation
        public let batchSize: Int
        
        /// Starting nonce value
        public let startNonce: UInt64
        
        /// Maximum nonce value before giving up
        public let maxNonce: UInt64
        
        /// Progress callback (called every batch)
        public let progressHandler: (@Sendable (UInt64, Double) -> Void)?
        
        public init(
            batchSize: Int = 10000,
            startNonce: UInt64 = 0,
            maxNonce: UInt64 = UInt64.max,
            progressHandler: (@Sendable (UInt64, Double) -> Void)? = nil
        ) {
            self.batchSize = max(1, batchSize)
            self.startNonce = startNonce
            self.maxNonce = maxNonce
            self.progressHandler = progressHandler
        }
        
        /// Default configuration
        public static let `default` = MiningConfig()
    }
    
    // MARK: - Mining
    
    /// Mine an event to achieve target difficulty
    /// - Parameters:
    ///   - event: The event to mine (will be modified with nonce)
    ///   - targetDifficulty: The number of leading zero bits required
    ///   - config: Mining configuration
    /// - Returns: The mined event with appropriate nonce
    /// - Throws: PoWError if mining fails or is cancelled
    public static func mine(
        event: NostrEvent,
        targetDifficulty: Int,
        config: MiningConfig = .default
    ) async throws -> NostrEvent {
        guard targetDifficulty >= 0 && targetDifficulty <= 256 else {
            throw PoWError.invalidDifficulty
        }
        
        // If difficulty is 0, no work needed
        if targetDifficulty == 0 {
            return event
        }
        
        // Remove any existing nonce tag
        let tags = event.tags.filter { $0.first != "nonce" }
        
        var nonce = config.startNonce
        let startTime = Date()
        var hashCount: UInt64 = 0
        
        while nonce <= config.maxNonce {
            // Check for cancellation periodically
            if Task.isCancelled {
                throw PoWError.miningCancelled
            }
            
            // Process a batch of nonces
            for _ in 0..<config.batchSize {
                // Create event with current nonce
                var eventTags = tags
                eventTags.append(["nonce", String(nonce), String(targetDifficulty)])
                
                let testEvent = NostrEvent(
                    pubkey: event.pubkey,
                    createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
                    kind: event.kind,
                    tags: eventTags,
                    content: event.content
                )
                
                let eventId = testEvent.calculateId()
                let difficulty = calculateDifficulty(eventId: eventId)
                
                hashCount += 1
                
                if difficulty >= targetDifficulty {
                    // Success! Return the mined event
                    return NostrEvent(
                        unvalidatedId: eventId,
                        pubkey: event.pubkey,
                        createdAt: event.createdAt,
                        kind: event.kind,
                        tags: eventTags,
                        content: event.content,
                        sig: event.sig
                    )
                }
                
                nonce += 1
                if nonce > config.maxNonce {
                    break
                }
            }
            
            // Report progress
            if let progressHandler = config.progressHandler {
                let elapsed = Date().timeIntervalSince(startTime)
                let hashRate = elapsed > 0 ? Double(hashCount) / elapsed : 0
                progressHandler(nonce, hashRate)
            }
        }
        
        throw PoWError.nonceOverflow
    }
    
    /// Mine with a timeout
    public static func mine(
        event: NostrEvent,
        targetDifficulty: Int,
        timeout: TimeInterval,
        config: MiningConfig = .default
    ) async throws -> NostrEvent {
        try await withThrowingTaskGroup(of: NostrEvent.self) { group in
            // Mining task
            group.addTask {
                try await mine(event: event, targetDifficulty: targetDifficulty, config: config)
            }
            
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw PoWError.miningTimeout
            }
            
            // Return first result (either mined event or timeout error)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Verification
    
    /// Verify that an event meets the minimum difficulty requirement
    /// - Parameters:
    ///   - event: The event to verify
    ///   - minimumDifficulty: The minimum number of leading zero bits required
    /// - Returns: true if the event meets or exceeds the difficulty requirement
    public static func verify(event: NostrEvent, minimumDifficulty: Int) -> Bool {
        guard minimumDifficulty >= 0 else { return false }
        
        // Check if event has a nonce tag
        let nonceTags = event.tags.filter { $0.first == "nonce" }
        
        // If minimum difficulty is 0, any event is valid
        if minimumDifficulty == 0 {
            return true
        }
        
        // For non-zero difficulty, must have nonce tag
        guard !nonceTags.isEmpty else { return false }
        
        // Calculate actual difficulty
        let actualDifficulty = calculateDifficulty(eventId: event.id)
        
        // Verify the claimed difficulty matches
        for nonceTag in nonceTags {
            if nonceTag.count >= 3,
               let claimedDifficulty = Int(nonceTag[2]) {
                // The actual difficulty should meet both claimed and minimum
                return actualDifficulty >= minimumDifficulty && actualDifficulty >= claimedDifficulty
            }
        }
        
        // If no valid nonce tag with difficulty, just check actual
        return actualDifficulty >= minimumDifficulty
    }
    
    /// Calculate the difficulty (number of leading zero bits) of an event ID
    /// - Parameter eventId: The event ID to check (hex string)
    /// - Returns: The number of leading zero bits
    public static func calculateDifficulty(eventId: String) -> Int {
        var leadingZeros = 0
        
        // Count leading zero hex characters (each represents 4 bits)
        for char in eventId {
            guard let nibble = char.hexDigitValue else { break }
            
            if nibble == 0 {
                leadingZeros += 4
            } else {
                // For non-zero nibbles, count the leading zero bits
                // within this nibble and stop
                if nibble == 1 {        // 0001
                    leadingZeros += 3
                } else if nibble < 4 {  // 0010, 0011
                    leadingZeros += 2
                } else if nibble < 8 {  // 0100, 0101, 0110, 0111
                    leadingZeros += 1
                }
                // else: 1000 or higher, no additional leading zeros
                break
            }
        }
        
        return leadingZeros
    }
    
    /// Extract the nonce value from an event
    /// - Parameter event: The event to check
    /// - Returns: The nonce value and claimed difficulty if present
    public static func extractNonce(from event: NostrEvent) -> (nonce: UInt64, difficulty: Int)? {
        for tag in event.tags {
            if tag.count >= 3 && tag[0] == "nonce",
               let nonce = UInt64(tag[1]),
               let difficulty = Int(tag[2]) {
                return (nonce, difficulty)
            }
        }
        return nil
    }
    
    /// Estimate time to mine at a given hash rate
    /// - Parameters:
    ///   - difficulty: Target difficulty in bits
    ///   - hashRate: Hashes per second
    /// - Returns: Estimated time in seconds
    public static func estimateTime(difficulty: Int, hashRate: Double) -> TimeInterval {
        guard difficulty > 0 && hashRate > 0 else { return 0 }
        
        // Expected number of hashes = 2^difficulty
        let expectedHashes = pow(2.0, Double(difficulty))
        return expectedHashes / hashRate
    }
    
    /// Calculate hash rate from mining statistics
    /// - Parameters:
    ///   - hashes: Number of hashes computed
    ///   - duration: Time taken in seconds
    /// - Returns: Hashes per second
    public static func calculateHashRate(hashes: UInt64, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return Double(hashes) / duration
    }
}

// MARK: - NostrEvent Extensions

public extension NostrEvent {
    /// The proof of work difficulty of this event
    var powDifficulty: Int {
        ProofOfWork.calculateDifficulty(eventId: id)
    }
    
    /// Check if this event has a proof of work nonce
    var hasProofOfWork: Bool {
        ProofOfWork.extractNonce(from: self) != nil
    }
    
    /// The nonce value if this event has proof of work
    var powNonce: UInt64? {
        ProofOfWork.extractNonce(from: self)?.nonce
    }
    
    /// The claimed difficulty from the nonce tag
    var claimedDifficulty: Int? {
        ProofOfWork.extractNonce(from: self)?.difficulty
    }
}

// MARK: - Convenience Methods

public extension CoreNostr {
    /// Create and mine an event with proof of work
    /// - Parameters:
    ///   - content: Event content
    ///   - kind: Event kind
    ///   - tags: Event tags (nonce will be added)
    ///   - difficulty: Target difficulty
    ///   - keyPair: Key pair for signing
    ///   - config: Mining configuration
    /// - Returns: Signed and mined event
    static func createMinedEvent(
        content: String,
        kind: Int = EventKind.textNote.rawValue,
        tags: [[String]] = [],
        difficulty: Int,
        keyPair: KeyPair,
        config: ProofOfWork.MiningConfig = .default
    ) async throws -> NostrEvent {
        // Create unsigned event
        let event = NostrEvent(
            pubkey: keyPair.publicKey,
            createdAt: Date(),
            kind: kind,
            tags: tags,
            content: content
        )
        
        // Mine it
        let minedEvent = try await ProofOfWork.mine(
            event: event,
            targetDifficulty: difficulty,
            config: config
        )
        
        // Sign the mined event
        return try keyPair.signEvent(minedEvent)
    }
}