import Testing
import Foundation
@testable import HomeBarCore

private func load<T: Decodable>(_ name: String, as: T.Type) throws -> T {
    let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json")!
    return try HAJSON.makeDecoder().decode(T.self, from: Data(contentsOf: url))
}

@Test func buildsAreaForEntityViaDevice() throws {
    let areas = try load("area_registry", as: [HAArea].self)
    let devices = try load("device_registry", as: [HADevice].self)
    let entities = try load("entity_registry", as: [EntityRegistryEntry].self)
    let registry = Registry(areas: areas, devices: devices, entities: entities)

    #expect(registry.areaName(for: "sensor.air_temperature") == "Living Room")
    #expect(registry.deviceName(for: "sensor.air_temperature") == "Air Sensor")
    #expect(registry.deviceID(for: "sensor.air_co2") == "dev_air")
}

@Test func entityLevelAreaOverridesDevice() throws {
    let registry = Registry(
        areas: try load("area_registry", as: [HAArea].self),
        devices: try load("device_registry", as: [HADevice].self),
        entities: try load("entity_registry", as: [EntityRegistryEntry].self))
    #expect(registry.areaName(for: "light.desk_lamp") == "Bedroom")
}

@Test func unknownEntityHasNoArea() throws {
    let registry = Registry(areas: [], devices: [], entities: [])
    #expect(registry.areaName(for: "sensor.nope") == nil)
}
