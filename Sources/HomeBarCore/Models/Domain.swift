public enum Domain: String, Sendable, CaseIterable {
    case sensor, binarySensor, switchType, light, climate, automation, scene, script, other

    public init(entityID: String) {
        let prefix = entityID.split(separator: ".").first.map(String.init) ?? ""
        switch prefix {
        case "sensor": self = .sensor
        case "binary_sensor": self = .binarySensor
        case "switch": self = .switchType
        case "light": self = .light
        case "climate": self = .climate
        case "automation": self = .automation
        case "scene": self = .scene
        case "script": self = .script
        default: self = .other
        }
    }
}
