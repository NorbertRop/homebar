import Foundation

public struct StateChange: Sendable, Equatable {
    public let entityID: String
    public let newState: EntityState?
}

public struct HistoryPoint: Sendable, Equatable {
    public let date: Date
    public let value: Double
    public init(date: Date, value: Double) { self.date = date; self.value = value }
}

public actor HAClient {
    public enum ConnectionState: Sendable, Equatable {
        case disconnected, connecting, authenticated, failed(String)
    }

    public private(set) var connectionState: ConnectionState = .disconnected
    public nonisolated let events: AsyncStream<StateChange>

    private let url: URL
    private let token: String
    private let transport: WebSocketTransport
    private let eventContinuation: AsyncStream<StateChange>.Continuation
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var receiveTask: Task<Void, Never>?

    public init(url: URL, token: String, transport: WebSocketTransport) {
        self.url = url; self.token = token; self.transport = transport
        (events, eventContinuation) = AsyncStream.makeStream(of: StateChange.self)
    }

    public func connect(timeout: TimeInterval = 15) async throws {
        connectionState = .connecting
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [transport, token] in
                    try await transport.connect()
                    guard frameType(try await transport.receive()) == "auth_required" else {
                        throw HAError.protocolError("expected auth_required")
                    }
                    try await transport.send(authFrame(token: token))
                    guard frameType(try await transport.receive()) == "auth_ok" else {
                        throw HAError.authFailed
                    }
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw HAError.timeout
                }
                defer { group.cancelAll() }
                do { try await group.next() }                  // first of handshake / timeout
                catch {
                    await transport.close()                    // unstick a handshake blocked on receive()
                    throw error
                }
            }
        } catch {
            connectionState = .disconnected
            throw error
        }
        connectionState = .authenticated
        startReceiveLoop()
    }

    public func getStates() async throws -> [EntityState] {
        let result = try await request(type: "get_states")
        let data = try HAJSON.makeEncoder().encode(result)
        return try HAJSON.makeDecoder().decode([EntityState].self, from: data)
    }

    public func fetchRegistry() async throws -> Registry {
        func list<T: Decodable>(_ type: String, _: T.Type) async throws -> T {
            let r = try await request(type: type)
            return try HAJSON.makeDecoder().decode(T.self, from: HAJSON.makeEncoder().encode(r))
        }
        let areas = try await list("config/area_registry/list", [HAArea].self)
        let devices = try await list("config/device_registry/list", [HADevice].self)
        let entities = try await list("config/entity_registry/list", [EntityRegistryEntry].self)
        return Registry(areas: areas, devices: devices, entities: entities)
    }

    public func subscribeStateChanges() async throws {
        let id = nextID; nextID += 1
        _ = try await sendAndWait(id: id, frame: subscribeFrame(id: id, eventType: "state_changed"))
    }

    public func send(_ call: ServiceCall) async throws {
        let id = nextID; nextID += 1
        _ = try await sendAndWait(id: id, frame: try callServiceFrame(id: id, call))
    }

    /// Heartbeat: round-trip a ping/pong. Throws on timeout, which tears the socket down and
    /// triggers a reconnect — this is how a connection that died during sleep is detected.
    public func ping() async throws {
        let id = nextID; nextID += 1
        _ = try await sendAndWait(id: id, frame: pingFrame(id: id), timeout: 10)
    }

    /// Numeric history samples for one entity over the last `hours`, oldest→newest.
    public func history(entityID: String, hours: Double) async throws -> [HistoryPoint] {
        let end = Date(), start = end.addingTimeInterval(-hours * 3600)
        let id = nextID; nextID += 1
        let frame = historyFrame(id: id, entityID: entityID, start: start, end: end)
        let result = try await sendAndWait(id: id, frame: frame)
        guard let arr = result[entityID]?.arrayValue else { return [] }
        return arr.compactMap { item in
            guard let v = (item["s"] ?? item["state"])?.coercedString.flatMap(Double.init) else { return nil }
            let ts = (item["lu"] ?? item["lc"])?.doubleValue
            return HistoryPoint(date: ts.map { Date(timeIntervalSince1970: $0) } ?? end, value: v)
        }
    }

    public func disconnect() async {
        receiveTask?.cancel(); receiveTask = nil
        await transport.close()
        failAllPending(HAError.notConnected)
        eventContinuation.finish()
        connectionState = .disconnected
    }

    private func request(type: String) async throws -> JSONValue {
        let id = nextID; nextID += 1
        return try await sendAndWait(id: id, frame: simpleFrame(id: id, type: type))
    }

    /// Send a frame and await its `result`, failing after `timeout`. Without this a request
    /// on a half-dead socket (e.g. after the Mac sleeps) would hang indefinitely.
    private func sendAndWait(id: Int, frame: String, timeout: TimeInterval = 12) async throws -> JSONValue {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<JSONValue, Error>) in
            pending[id] = c
            Task { try? await self.transport.send(frame) }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                await self?.timedOut(id)
            }
        }
    }
    /// A request got no reply in time — a strong signal the socket is dead. Fail it and tear the
    /// connection down so the connect loop reconnects.
    private func timedOut(_ id: Int) {
        guard let c = pending.removeValue(forKey: id) else { return }
        c.resume(throwing: HAError.timeout)
        teardown(HAError.timeout)
    }

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do { await self.handle(try await self.transport.receive()) }
                catch { await self.teardown(error); return }
            }
        }
    }
    /// The socket died: stop receiving, fail in-flight requests, and end the events stream so the
    /// app's connect loop stops awaiting and reconnects. Idempotent.
    private func teardown(_ error: Error) {
        receiveTask?.cancel(); receiveTask = nil
        failAllPending(error)
        eventContinuation.finish()
        connectionState = .disconnected
    }

    private func handle(_ frame: String) {
        guard let obj = try? HAJSON.makeDecoder().decode(JSONValue.self, from: Data(frame.utf8)) else { return }
        switch obj["type"]?.stringValue {
        case "result":
            guard let id = obj["id"]?.intValue, let c = pending.removeValue(forKey: id) else { return }
            if obj["success"]?.boolValue == true { c.resume(returning: obj["result"] ?? .null) }
            else { c.resume(throwing: HAError.serviceCallFailed(obj["error"]?["message"]?.stringValue ?? "unknown")) }
        case "pong":
            if let id = obj["id"]?.intValue, let c = pending.removeValue(forKey: id) { c.resume(returning: .null) }
        case "event":
            if let change = Self.parseStateChanged(obj) { eventContinuation.yield(change) }
        default: break
        }
    }

    private func failAllPending(_ error: Error) {
        for (_, c) in pending { c.resume(throwing: error) }
        pending.removeAll()
    }

    static func parseStateChanged(_ obj: JSONValue) -> StateChange? {
        guard obj["event"]?["event_type"]?.stringValue == "state_changed",
              let data = obj["event"]?["data"],
              let entityID = data["entity_id"]?.stringValue else { return nil }
        let newState: EntityState?
        if let ns = data["new_state"], !ns.isNull,
           let encoded = try? HAJSON.makeEncoder().encode(ns) {
            newState = try? HAJSON.makeDecoder().decode(EntityState.self, from: encoded)
        } else { newState = nil }
        return StateChange(entityID: entityID, newState: newState)
    }
}

func frameType(_ frame: String) -> String? {
    (try? HAJSON.makeDecoder().decode(JSONValue.self, from: Data(frame.utf8)))?["type"]?.stringValue
}
