import Testing
import Foundation
@testable import HomeBarCore

private func reg() throws -> Registry {
    func load<T: Decodable>(_ n: String) throws -> T {
        let u = Bundle.module.url(forResource: "Fixtures/\(n)", withExtension: "json")!
        return try HAJSON.makeDecoder().decode(T.self, from: Data(contentsOf: u))
    }
    return Registry(areas: try load("area_registry"), devices: try load("device_registry"),
                    entities: try load("entity_registry"))
}

private func states() throws -> [EntityState] {
    let u = Bundle.module.url(forResource: "Fixtures/states", withExtension: "json")!
    return try HAJSON.makeDecoder().decode([EntityState].self, from: Data(contentsOf: u))
}

@Test func groupsByAreaWithDeviceCardAndPinned() throws {
    var settings = Settings()
    settings.pinned = ["light.desk_lamp"]
    let nonAutomation = try states().filter { $0.domain != .automation }
    let grouped = groupEntities(nonAutomation, registry: try reg(), settings: settings)

    #expect(grouped.pinned == ["light.desk_lamp"])
    let living = grouped.areas.first { $0.name == "Living Room" }!
    let airCard = living.deviceCards.first { $0.name == "Air Sensor" }!
    #expect(Set(airCard.entityIDs) == ["sensor.air_temperature", "sensor.air_co2"])
    #expect(living.looseEntityIDs.contains("climate.living_room_ac"))
}

@Test func hiddenAreExcludedAndNoAreaGoesUnassigned() throws {
    var settings = Settings()
    settings.hidden = ["sensor.air_co2"]
    let grouped = groupEntities([
        EntityState(entityID: "sensor.air_co2", state: "1", attributes: [:], lastChanged: .now, lastUpdated: .now),
        EntityState(entityID: "sensor.orphan", state: "1", attributes: [:], lastChanged: .now, lastUpdated: .now),
    ], registry: try reg(), settings: settings)
    #expect(grouped.areas.allSatisfy { !$0.looseEntityIDs.contains("sensor.air_co2") })
    #expect(grouped.unassigned.looseEntityIDs.contains("sensor.orphan"))
}

@Test func hidesOfflineAndNoiseDomainsByDefaultUnlessPinned() throws {
    func e(_ id: String, _ state: String) -> EntityState {
        EntityState(entityID: id, state: state, attributes: [:], lastChanged: .now, lastUpdated: .now)
    }
    let entities = [e("light.online", "on"), e("light.offline", "unavailable"), e("update.firmware", "on")]

    let g = groupEntities(entities, registry: try reg(), settings: Settings())  // hideOffline default true
    let shown = Set(g.pinned + g.areas.flatMap { $0.looseEntityIDs }
                    + g.unassigned.looseEntityIDs
                    + g.areas.flatMap { $0.deviceCards.flatMap(\.entityIDs) })
    #expect(shown.contains("light.online"))
    #expect(!shown.contains("light.offline"))    // hidden: offline
    #expect(!shown.contains("update.firmware"))  // hidden: noise domain

    var pinned = Settings(); pinned.pinned = ["light.offline", "update.firmware"]
    let g2 = groupEntities(entities, registry: try reg(), settings: pinned)
    #expect(g2.pinned == ["light.offline", "update.firmware"])  // pinning overrides both filters
}

@Test func hidesDiagnosticEntitiesUnlessShown() {
    let registry = Registry(areas: [], devices: [], entities: [
        EntityRegistryEntry(entityID: "sensor.uptime", entityCategory: "diagnostic"),
        EntityRegistryEntry(entityID: "switch.auto_update", entityCategory: "config"),
        EntityRegistryEntry(entityID: "sensor.temp", entityCategory: nil),
    ])
    func e(_ id: String) -> EntityState {
        EntityState(entityID: id, state: "on", attributes: [:], lastChanged: .now, lastUpdated: .now)
    }
    let states = [e("sensor.uptime"), e("switch.auto_update"), e("sensor.temp")]

    var s = Settings()
    let shown = { (g: GroupedEntities) in Set(g.pinned + g.areas.flatMap { $0.looseEntityIDs } + g.unassigned.looseEntityIDs) }
    let hidden = shown(groupEntities(states, registry: registry, settings: s))
    #expect(hidden.contains("sensor.temp"))
    #expect(!hidden.contains("sensor.uptime"))        // diagnostic hidden
    #expect(!hidden.contains("switch.auto_update"))   // config hidden

    s.showDiagnostic = true
    let all = shown(groupEntities(states, registry: registry, settings: s))
    #expect(all.contains("sensor.uptime") && all.contains("switch.auto_update"))
}

@Test func hidesWholeDeviceWhenConnectivityDisconnected() {
    let registry = Registry(areas: [], devices: [], entities: [
        EntityRegistryEntry(entityID: "binary_sensor.esp_conn", deviceID: "esp"),
        EntityRegistryEntry(entityID: "light.esp_led", deviceID: "esp"),
        EntityRegistryEntry(entityID: "light.other", deviceID: "other"),
    ])
    func e(_ id: String, _ state: String, dc: String? = nil) -> EntityState {
        var a: [String: JSONValue] = [:]; if let dc { a["device_class"] = .string(dc) }
        return EntityState(entityID: id, state: state, attributes: a, lastChanged: .now, lastUpdated: .now)
    }
    let states = [e("binary_sensor.esp_conn", "off", dc: "connectivity"), e("light.esp_led", "off"), e("light.other", "on")]
    let g = groupEntities(states, registry: registry, settings: Settings())
    let shown = Set(g.pinned + g.areas.flatMap { $0.looseEntityIDs } + g.unassigned.looseEntityIDs)
    #expect(!shown.contains("binary_sensor.esp_conn"))  // disconnected device hidden…
    #expect(!shown.contains("light.esp_led"))           // …including its controls
    #expect(shown.contains("light.other"))              // other devices unaffected
}

@Test func customOrderPutsKnownFirstThenKeepsTheRest() {
    #expect(ordered(["c", "a", "b", "d"], by: ["b", "a"]) == ["b", "a", "c", "d"])
    #expect(ordered(["x", "y"], by: []) == ["x", "y"])   // no custom order → unchanged
}

@Test func entityVisibilityReportsTheRightReason() {
    let registry = Registry(areas: [], devices: [], entities: [
        EntityRegistryEntry(entityID: "sensor.uptime", entityCategory: "diagnostic"),
    ])
    func e(_ id: String, _ state: String = "on") -> EntityState {
        EntityState(entityID: id, state: state, attributes: [:], lastChanged: .now, lastUpdated: .now)
    }
    var s = Settings(); s.hidden = ["sensor.manual"]; s.pinned = ["update.kept", "sensor.dead"]
    func vis(_ id: String, _ state: String = "on") -> EntityVisibility {
        entityVisibility(e(id, state), registry: registry, settings: s, disconnectedDevices: [])
    }
    #expect(vis("sensor.temp") == .shown)
    #expect(vis("sensor.manual") == .hidden(.manual))
    #expect(vis("update.firmware") == .hidden(.domain))      // not a dashboard domain
    #expect(vis("update.kept") == .shown)                    // pinned overrides the domain filter
    #expect(vis("sensor.uptime") == .hidden(.diagnostic))
    #expect(vis("sensor.air", "unavailable") == .hidden(.offline))
    // Pinned entity on a disconnected device still shows (pin wins over device-offline).
    #expect(entityVisibility(e("sensor.dead"), registry: registry, settings: s,
                             disconnectedDevices: ["dev1"]) == .shown)
}
