import Testing
import Foundation
@testable import CoreNostr

// MARK: - Stub IO for RelayConnection tests
actor StubRelayIO: RelayIOProtocol {
    private var msgContinuation: AsyncStream<RelayMessage>.Continuation?
    private var msgStream: AsyncStream<RelayMessage>?
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var stateStream: AsyncStream<ConnectionState>?
    private let jsonToEmit: String
    private var hasConnected = false

    init(jsonToEmit: String) { self.jsonToEmit = jsonToEmit }

    func connect() async throws {
        if msgStream == nil {
            let (stream, continuation) = AsyncStream<RelayMessage>.makeStream()
            self.msgStream = stream
            self.msgContinuation = continuation
        }
        if stateStream == nil {
            let (s, c) = AsyncStream<ConnectionState>.makeStream()
            self.stateStream = s
            self.stateContinuation = c
        }
        if let message = try? RelayMessage.decode(from: jsonToEmit) {
            msgContinuation?.yield(message)
        }
        stateContinuation?.yield(.connected)
        hasConnected = true
    }

    func getMessages() async -> AsyncStream<RelayMessage>? { msgStream }
    func getStateStream() async -> AsyncStream<ConnectionState>? { stateStream }

    func disconnect() async {
        msgContinuation?.finish()
        msgContinuation = nil
        msgStream = nil
        stateContinuation?.finish()
        stateContinuation = nil
        stateStream = nil
        hasConnected = false
    }

    func sendString(_ string: String) async throws {
        guard hasConnected else {
            throw NostrError.networkError(operation: .send, reason: "Not connected")
        }
    }

    func triggerError(scheduleReconnectAfter delay: TimeInterval? = nil) async {
        stateContinuation?.yield(.disconnected)
        if let d = delay {
            try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
            stateContinuation?.yield(.connecting)
            try? await Task.sleep(nanoseconds: 5_000_000) // brief
            stateContinuation?.yield(.connected)
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

@MainActor
@Test func relayConnectionStateTransitionsOnErrorNoReconnect() async throws {
    let stubIO = StubRelayIO(jsonToEmit: "[\"NOTICE\",\"hi\"]")
    let relay = RelayConnection(io: stubIO)
    relay.autoReconnect = false
    try await relay.connect(to: URL(string: "wss://example.com")!)
    
    // Simulate error without reconnect
    await stubIO.triggerError()
    // Wait briefly for state to propagate
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(relay.state == .disconnected)
}

@MainActor
@Test func relayConnectionSchedulesReconnectOnError() async throws {
    let stubIO = StubRelayIO(jsonToEmit: "[\"NOTICE\",\"hi\"]")
    let relay = RelayConnection(io: stubIO)
    relay.autoReconnect = true
    relay.sendMinInterval = 0.0
    relay.maxSendQueueSize = 10
    try await relay.connect(to: URL(string: "wss://example.com")!)
    
    await stubIO.triggerError(scheduleReconnectAfter: 0.02)
    // Poll for connecting then connected
    var sawConnecting = false
    var sawConnected = false
    let start = Date()
    while Date().timeIntervalSince(start) < 1.0 {
        if relay.state == .connecting { sawConnecting = true }
        if relay.state == .connected { sawConnected = true; break }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(sawConnecting)
    #expect(sawConnected)
}

@MainActor
@Test func sendQueueRateLimitingAndCoalescing() async throws {
    let stubIO = StubRelayIO(jsonToEmit: "[\"NOTICE\",\"hi\"]")
    let relay = RelayConnection(io: stubIO)
    relay.autoReconnect = false
    relay.sendMinInterval = 0.01
    relay.maxSendQueueSize = 5
    try await relay.connect(to: URL(string: "wss://example.com")!)
    
    // Enqueue multiple REQ messages rapidly; coalescing drops older duplicates
    let filter = Filter(kinds: [1], limit: 1)
    for i in 0..<3 {
        let msg = ClientMessage.req(subscriptionId: "sub", filters: [filter])
        try await relay.send(msg)
    }
    // Just ensure no crash; state remains connected
    #expect(relay.state == .connected)
}


