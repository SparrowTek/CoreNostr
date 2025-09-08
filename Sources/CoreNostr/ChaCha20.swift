import Foundation

/// ChaCha20 stream cipher implementation (RFC 8439)
struct ChaCha20 {
    private let key: Data
    private let nonce: Data
    private var counter: UInt32
    
    /// Initialize ChaCha20 cipher
    /// - Parameters:
    ///   - key: 32-byte encryption key
    ///   - nonce: 12-byte nonce
    ///   - counter: Initial counter value (default: 0)
    /// - Throws: Error if key or nonce have incorrect size
    init(key: Data, nonce: Data, counter: UInt32 = 0) throws {
        guard key.count == 32 else {
            throw NostrError.encryptionError(operation: .encrypt, reason: "ChaCha20 key must be 32 bytes")
        }
        guard nonce.count == 12 else {
            throw NostrError.encryptionError(operation: .encrypt, reason: "ChaCha20 nonce must be 12 bytes")
        }
        
        self.key = key
        self.nonce = nonce
        self.counter = counter
    }
    
    /// Process data (encrypt or decrypt)
    /// - Parameter data: Data to process
    /// - Returns: Processed data
    func process(_ data: Data) -> Data {
        var output = Data(capacity: data.count)
        var currentCounter = counter
        
        // Process in 64-byte blocks
        for chunkStart in stride(from: 0, to: data.count, by: 64) {
            let chunkEnd = min(chunkStart + 64, data.count)
            let chunk = data[chunkStart..<chunkEnd]
            
            let keystream = generateKeystream(counter: currentCounter)
            
            for (i, byte) in chunk.enumerated() {
                output.append(byte ^ keystream[i])
            }
            
            currentCounter += 1
        }
        
        return output
    }
    
    /// Generate 64-byte keystream block
    private func generateKeystream(counter: UInt32) -> Data {
        var state = initializeState(counter: counter)
        
        // 20 rounds (10 double-rounds)
        for _ in 0..<10 {
            // Column rounds
            quarterRound(&state, 0, 4, 8, 12)
            quarterRound(&state, 1, 5, 9, 13)
            quarterRound(&state, 2, 6, 10, 14)
            quarterRound(&state, 3, 7, 11, 15)
            
            // Diagonal rounds
            quarterRound(&state, 0, 5, 10, 15)
            quarterRound(&state, 1, 6, 11, 12)
            quarterRound(&state, 2, 7, 8, 13)
            quarterRound(&state, 3, 4, 9, 14)
        }
        
        // Add initial state
        let initialState = initializeState(counter: counter)
        for i in 0..<16 {
            state[i] = state[i] &+ initialState[i]
        }
        
        // Serialize state to bytes
        var output = Data(capacity: 64)
        for word in state {
            withUnsafeBytes(of: word.littleEndian) { bytes in
                output.append(contentsOf: bytes)
            }
        }
        
        return output
    }
    
    /// Initialize ChaCha20 state
    private func initializeState(counter: UInt32) -> [UInt32] {
        var state = [UInt32](repeating: 0, count: 16)
        
        // Constants "expand 32-byte k"
        state[0] = 0x61707865
        state[1] = 0x3320646e
        state[2] = 0x79622d32
        state[3] = 0x6b206574
        
        // Key (32 bytes = 8 words)
        key.withUnsafeBytes { bytes in
            let words = bytes.bindMemory(to: UInt32.self)
            for i in 0..<8 {
                state[4 + i] = words[i].littleEndian
            }
        }
        
        // Counter
        state[12] = counter
        
        // Nonce (12 bytes = 3 words)
        nonce.withUnsafeBytes { bytes in
            let words = bytes.bindMemory(to: UInt32.self)
            for i in 0..<3 {
                state[13 + i] = words[i].littleEndian
            }
        }
        
        return state
    }
    
    /// ChaCha20 quarter round
    private func quarterRound(_ state: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        state[a] = state[a] &+ state[b]
        state[d] ^= state[a]
        state[d] = rotateLeft(state[d], 16)
        
        state[c] = state[c] &+ state[d]
        state[b] ^= state[c]
        state[b] = rotateLeft(state[b], 12)
        
        state[a] = state[a] &+ state[b]
        state[d] ^= state[a]
        state[d] = rotateLeft(state[d], 8)
        
        state[c] = state[c] &+ state[d]
        state[b] ^= state[c]
        state[b] = rotateLeft(state[b], 7)
    }
    
    /// Rotate left
    private func rotateLeft(_ value: UInt32, _ amount: Int) -> UInt32 {
        return (value << amount) | (value >> (32 - amount))
    }
}