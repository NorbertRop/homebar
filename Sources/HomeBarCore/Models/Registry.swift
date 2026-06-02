public struct HAArea: Sendable, Codable, Equatable {
    public let areaID: String
    public let name: String
    enum CodingKeys: String, CodingKey { case areaID = "area_id", name }
}

public struct HADevice: Sendable, Codable, Equatable {
    public let id: String
    public let name: String?
    public let areaID: String?
    enum CodingKeys: String, CodingKey { case id, name, areaID = "area_id" }
}

public struct EntityRegistryEntry: Sendable, Codable, Equatable {
    public let entityID: String
    public let deviceID: String?
    public let areaID: String?
    public let entityCategory: String?   // "diagnostic", "config", or nil
    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id", deviceID = "device_id", areaID = "area_id", entityCategory = "entity_category"
    }
    public init(entityID: String, deviceID: String? = nil, areaID: String? = nil, entityCategory: String? = nil) {
        self.entityID = entityID; self.deviceID = deviceID; self.areaID = areaID
        self.entityCategory = entityCategory
    }
}

/// Resolves entity → device → area, honoring entity-level area overrides.
public struct Registry: Sendable {
    private let areaNames: [String: String]
    private let devices: [String: HADevice]
    private let entities: [String: EntityRegistryEntry]

    public init(areas: [HAArea], devices: [HADevice], entities: [EntityRegistryEntry]) {
        self.areaNames = Dictionary(areas.map { ($0.areaID, $0.name) }) { a, _ in a }
        self.devices = Dictionary(devices.map { ($0.id, $0) }) { a, _ in a }
        self.entities = Dictionary(entities.map { ($0.entityID, $0) }) { a, _ in a }
    }

    public func deviceID(for entityID: String) -> String? { entities[entityID]?.deviceID }

    public func deviceName(for entityID: String) -> String? {
        guard let did = deviceID(for: entityID) else { return nil }
        return devices[did]?.name
    }

    public func areaName(for entityID: String) -> String? {
        if let aid = entities[entityID]?.areaID { return areaNames[aid] }
        if let did = entities[entityID]?.deviceID, let aid = devices[did]?.areaID {
            return areaNames[aid]
        }
        return nil
    }

    /// HA marks battery/signal/uptime/connectivity/config entities with an entity_category;
    /// these are noise for a dashboard.
    public func isDiagnostic(_ entityID: String) -> Bool {
        let c = entities[entityID]?.entityCategory
        return c == "diagnostic" || c == "config"
    }
}
