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
