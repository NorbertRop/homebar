import Foundation

public struct StateChange: Sendable, Equatable {
    public let entityID: String
    public let newState: EntityState?
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

    public func connect() async throws {
        connectionState = .connecting
        try await transport.connect()
        guard frameType(try await transport.receive()) == "auth_required" else {
            throw HAError.protocolError("expected auth_required")
        }
        try await transport.send(authFrame(token: token))
        let resp = try await transport.receive()
        guard frameType(resp) == "auth_ok" else {
            connectionState = .failed("auth")
            throw HAError.authFailed
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
        _ = try await withCheckedThrowingContinuation { (c: CheckedContinuation<JSONValue, Error>) in
            pending[id] = c
            Task { try? await self.transport.send(subscribeFrame(id: id, eventType: "state_changed")) }
        }
    }

    public func send(_ call: ServiceCall) async throws {
        let id = nextID; nextID += 1
        let frame = try callServiceFrame(id: id, call)
        _ = try await withCheckedThrowingContinuation { (c: CheckedContinuation<JSONValue, Error>) in
            pending[id] = c
            Task { try? await self.transport.send(frame) }
        }
    }

    /// Numeric history samples for one entity over the last `hours`, oldest→newest.
    public func history(entityID: String, hours: Double) async throws -> [Double] {
        let end = Date(), start = end.addingTimeInterval(-hours * 3600)
        let id = nextID; nextID += 1
        let frame = historyFrame(id: id, entityID: entityID, start: start, end: end)
        let result = try await withCheckedThrowingContinuation { (c: CheckedContinuation<JSONValue, Error>) in
            pending[id] = c
            Task { try? await self.transport.send(frame) }
        }
        guard let arr = result[entityID]?.arrayValue else { return [] }
        return arr.compactMap { item in
            (item["s"] ?? item["state"])?.coercedString.flatMap(Double.init)
        }
    }

    public func disconnect() async {
        receiveTask?.cancel(); receiveTask = nil
        await transport.close()
        failAllPending(HAError.notConnected)
        connectionState = .disconnected
    }

    private func request(type: String) async throws -> JSONValue {
        let id = nextID; nextID += 1
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<JSONValue, Error>) in
            pending[id] = c
            Task { try? await self.transport.send(simpleFrame(id: id, type: type)) }
        }
    }

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do { await self.handle(try await self.transport.receive()) }
                catch { await self.failAllPending(error); return }
            }
        }
    }

    private func handle(_ frame: String) {
        guard let obj = try? HAJSON.makeDecoder().decode(JSONValue.self, from: Data(frame.utf8)) else { return }
        switch obj["type"]?.stringValue {
        case "result":
            guard let id = obj["id"]?.intValue, let c = pending.removeValue(forKey: id) else { return }
            if obj["success"]?.boolValue == true { c.resume(returning: obj["result"] ?? .null) }
            else { c.resume(throwing: HAError.serviceCallFailed(obj["error"]?["message"]?.stringValue ?? "unknown")) }
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
