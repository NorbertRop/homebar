import Foundation

public struct ServiceCall: Sendable, Equatable {
    public let domain: String
    public let service: String
    public let data: [String: JSONValue]
    public let target: String   // entity_id
    public init(domain: String, service: String, data: [String: JSONValue], target: String) {
        self.domain = domain; self.service = service; self.data = data; self.target = target
    }
}

public enum HACommand {
    public static func toggle(_ entityID: String) -> ServiceCall {
        ServiceCall(domain: entityDomain(entityID), service: "toggle", data: [:], target: entityID)
    }
    public static func turnOn(_ entityID: String) -> ServiceCall {
        ServiceCall(domain: entityDomain(entityID), service: "turn_on", data: [:], target: entityID)
    }
    public static func turnOff(_ entityID: String) -> ServiceCall {
        ServiceCall(domain: entityDomain(entityID), service: "turn_off", data: [:], target: entityID)
    }
    public static func setLight(_ entityID: String, on: Bool, brightnessPercent: Int?,
                                rgb: RGB?, colorTempKelvin: Int?) -> ServiceCall {
        guard on else { return ServiceCall(domain: "light", service: "turn_off", data: [:], target: entityID) }
        var data: [String: JSONValue] = [:]
        if let b = brightnessPercent { data["brightness_pct"] = .int(b) }
        if let c = rgb { data["rgb_color"] = .array([.int(c.r), .int(c.g), .int(c.b)]) }
        if let k = colorTempKelvin { data["color_temp_kelvin"] = .int(k) }
        return ServiceCall(domain: "light", service: "turn_on", data: data, target: entityID)
    }
    public static func setClimateTemperature(_ entityID: String, _ temp: Double) -> ServiceCall {
        ServiceCall(domain: "climate", service: "set_temperature",
                    data: ["temperature": .double(temp)], target: entityID)
    }
    public static func setClimateMode(_ entityID: String, _ mode: String) -> ServiceCall {
        ServiceCall(domain: "climate", service: "set_hvac_mode",
                    data: ["hvac_mode": .string(mode)], target: entityID)
    }
    public static func setClimateFan(_ entityID: String, _ mode: String) -> ServiceCall {
        ServiceCall(domain: "climate", service: "set_fan_mode",
                    data: ["fan_mode": .string(mode)], target: entityID)
    }
    public static func runAutomation(_ entityID: String) -> ServiceCall {
        ServiceCall(domain: "automation", service: "trigger", data: [:], target: entityID)
    }
    public static func armAutomation(_ entityID: String, armed: Bool) -> ServiceCall {
        ServiceCall(domain: "automation", service: armed ? "turn_on" : "turn_off",
                    data: [:], target: entityID)
    }
}

public func authFrame(token: String) -> String {
    encode(["type": .string("auth"), "access_token": .string(token)])
}
public func simpleFrame(id: Int, type: String) -> String {
    encode(["id": .int(id), "type": .string(type)])
}
public func pingFrame(id: Int) -> String {
    encode(["id": .int(id), "type": .string("ping")])
}
public func subscribeFrame(id: Int, eventType: String) -> String {
    encode(["id": .int(id), "type": .string("subscribe_events"), "event_type": .string(eventType)])
}
public func historyFrame(id: Int, entityID: String, start: Date, end: Date) -> String {
    let iso = ISO8601DateFormatter()
    return encode([
        "id": .int(id), "type": .string("history/history_during_period"),
        "start_time": .string(iso.string(from: start)), "end_time": .string(iso.string(from: end)),
        "entity_ids": .array([.string(entityID)]),
        "minimal_response": .bool(true), "no_attributes": .bool(true),
    ])
}
public func callServiceFrame(id: Int, _ call: ServiceCall) throws -> String {
    var obj: [String: JSONValue] = [
        "id": .int(id), "type": .string("call_service"),
        "domain": .string(call.domain), "service": .string(call.service),
        "target": .object(["entity_id": .string(call.target)]),
    ]
    if !call.data.isEmpty { obj["service_data"] = .object(call.data) }
    return encode(obj)
}
private func encode(_ obj: [String: JSONValue]) -> String {
    let data = (try? HAJSON.makeEncoder().encode(JSONValue.object(obj))) ?? Data()
    return String(decoding: data, as: UTF8.self)
}
