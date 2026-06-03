import Foundation

public struct EntityState: Sendable, Equatable, Codable, Identifiable {
    public let entityID: String
    public let state: String
    public let attributes: [String: JSONValue]
    public let lastChanged: Date
    public let lastUpdated: Date

    public var id: String { entityID }

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }

    public init(entityID: String, state: String, attributes: [String: JSONValue],
                lastChanged: Date, lastUpdated: Date) {
        self.entityID = entityID; self.state = state; self.attributes = attributes
        self.lastChanged = lastChanged; self.lastUpdated = lastUpdated
    }

    public var domain: Domain { Domain(entityID: entityID) }
    public var friendlyName: String { attributes["friendly_name"]?.stringValue ?? entityID }
    public var unit: String? { attributes["unit_of_measurement"]?.stringValue }
    public var deviceClass: String? { attributes["device_class"]?.stringValue }
    public var isAvailable: Bool { state != "unavailable" && state != "unknown" }
    public var isOn: Bool { state == "on" }
}
