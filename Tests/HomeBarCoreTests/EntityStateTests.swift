import Testing
import Foundation
@testable import HomeBarCore

private func loadStates() throws -> [EntityState] {
    let url = Bundle.module.url(forResource: "Fixtures/states", withExtension: "json")!
    return try HAJSON.makeDecoder().decode([EntityState].self, from: Data(contentsOf: url))
}

@Test func decodesAllEntities() throws {
    let states = try loadStates()
    #expect(states.count == 6)
}

@Test func parsesDomainFromEntityID() {
    #expect(Domain(entityID: "sensor.air_temperature") == .sensor)
    #expect(Domain(entityID: "binary_sensor.balcony_door") == .binarySensor)
    #expect(Domain(entityID: "switch.x") == .switchType)
    #expect(Domain(entityID: "light.x") == .light)
    #expect(Domain(entityID: "climate.x") == .climate)
    #expect(Domain(entityID: "automation.x") == .automation)
    #expect(Domain(entityID: "weird.x") == .other)
}

@Test func exposesFriendlyNameUnitAndDeviceClass() throws {
    let states = try loadStates()
    let temp = states.first { $0.entityID == "sensor.air_temperature" }!
    #expect(temp.friendlyName == "Air Temperature")
    #expect(temp.unit == "°C")
    #expect(temp.deviceClass == "temperature")
    #expect(temp.isAvailable == true)
}

@Test func detectsUnavailable() {
    let s = EntityState(entityID: "sensor.x", state: "unavailable",
                        attributes: [:], lastChanged: .now, lastUpdated: .now)
    #expect(s.isAvailable == false)
}
