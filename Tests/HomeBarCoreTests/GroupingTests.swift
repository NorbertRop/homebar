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
