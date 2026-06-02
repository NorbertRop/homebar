import Foundation

/// Test double: tests enqueue inbound frames and inspect captured outbound frames.
public actor FakeWebSocketTransport: WebSocketTransport {
    public private(set) var sent: [String] = []
    private var inbound: [String] = []
    private var waiters: [CheckedContinuation<String, Error>] = []
    public private(set) var didConnect = false
    public private(set) var didClose = false

    public init() {}

    public func connect() async throws { didConnect = true }
    public func send(_ text: String) async throws { sent.append(text) }

    public func receive() async throws -> String {
        if !inbound.isEmpty { return inbound.removeFirst() }
        return try await withCheckedThrowingContinuation { waiters.append($0) }
    }
    public func close() async { didClose = true }

    /// Push a frame "from the server".
    public func enqueue(_ frame: String) {
        if !waiters.isEmpty { waiters.removeFirst().resume(returning: frame) }
        else { inbound.append(frame) }
    }
}
