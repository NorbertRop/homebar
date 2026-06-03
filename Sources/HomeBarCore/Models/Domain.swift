public enum Domain: String, Sendable, CaseIterable {
    case sensor, binarySensor, switchType, light, climate, automation, scene, script, vacuum, other

    public init(entityID: String) {
        switch entityDomain(entityID) {
        case "sensor": self = .sensor
        case "binary_sensor": self = .binarySensor
        case "switch": self = .switchType
        case "light": self = .light
        case "climate": self = .climate
        case "automation": self = .automation
        case "scene": self = .scene
        case "script": self = .script
        case "vacuum": self = .vacuum
        default: self = .other
        }
    }
}

/// The domain part of an entity_id ("light.desk" → "light"). The single place this split lives.
public func entityDomain(_ entityID: String) -> String {
    String(entityID.split(separator: ".").first ?? "")
}
