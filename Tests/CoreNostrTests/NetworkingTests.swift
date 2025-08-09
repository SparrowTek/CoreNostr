import Testing
import Foundation
@testable import CoreNostr

// MARK: - Stub IO for RelayConnection tests
actor StubRelayIO: RelayIOProtocol {
    private var continuation: AsyncStream<RelayMessage>.Continuation?
    private var stream: AsyncStream<RelayMessage>?
    private let jsonToEmit: String
    private var hasConnected = false

    init(jsonToEmit: String) { self.jsonToEmit = jsonToEmit }

    func connect() async throws {
        let (stream, continuation) = AsyncStream<RelayMessage>.makeStream()
        self.stream = stream
        self.continuation = continuation
        if let message = try? RelayMessage.decode(from: jsonToEmit) {
            continuation.yield(message)
        }
        hasConnected = true
    }

    func getMessages() async -> AsyncStream<RelayMessage>? { stream }

    func disconnect() async {
        continuation?.finish()
        continuation = nil
        stream = nil
    }

    func sendString(_ string: String) async throws {
        guard hasConnected else {
            throw NostrError.networkError(operation: .send, reason: "Not connected")
        }
    }
}

@MainActor
@Test func relayConnectionReceivesMessageAfterConnect() async throws {
    // Valid EVENT JSON per protocol
    let eventJson = "[\"EVENT\",\"sub1\",{\"id\":\"abc123\",\"pubkey\":\"def456\",\"created_at\":1234567890,\"kind\":1,\"tags\":[],\"content\":\"Hello\",\"sig\":\"signature123\"}]"
    let stubIO = StubRelayIO(jsonToEmit: eventJson)
    let relay = await RelayConnection(io: stubIO)
    try await relay.connect(to: URL(string: "wss://example.com")!)
    
    var received: RelayMessage?
    var iterator = relay.messages.makeAsyncIterator()
    received = await iterator.next()
    
    #expect(received != nil)
    if case .event(let subId, let event) = received! {
        #expect(subId == "sub1")
        #expect(event.content == "Hello")
    } else {
        #expect(Bool(false), "Expected EVENT message after connect")
    }
}


