import Foundation

public protocol WebSocketTransport: Sendable {
    func connect() async throws
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close() async
}

public actor URLSessionWebSocketTransport: WebSocketTransport {
    private let url: URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    public init(url: URL, session: URLSession = .shared) { self.url = url; self.session = session }

    public func connect() async throws {
        let t = session.webSocketTask(with: url)
        t.resume()
        task = t
    }
    public func send(_ text: String) async throws {
        guard let task else { throw HAError.notConnected }
        try await task.send(.string(text))
    }
    public func receive() async throws -> String {
        guard let task else { throw HAError.notConnected }
        switch try await task.receive() {
        case .string(let s): return s
        case .data(let d): return String(decoding: d, as: UTF8.self)
        @unknown default: throw HAError.protocolError("unknown frame")
        }
    }
    public func close() async { task?.cancel(with: .goingAway, reason: nil); task = nil }
}

public enum HAError: Error, Equatable {
    case notConnected
    case authFailed
    case protocolError(String)
    case serviceCallFailed(String)
}
