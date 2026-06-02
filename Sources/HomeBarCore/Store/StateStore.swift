import Foundation
import Observation

@MainActor @Observable public final class StateStore {
    public private(set) var entities: [String: EntityState] = [:]
    public var registry = Registry(areas: [], devices: [], entities: [])

    public init() {}

    public func applySnapshot(_ states: [EntityState]) {
        entities = Dictionary(states.map { ($0.entityID, $0) }) { a, _ in a }
    }

    public func apply(_ change: StateChange) {
        if let s = change.newState { entities[change.entityID] = s }
        else { entities.removeValue(forKey: change.entityID) }
    }

    public func saveCache(to url: URL) throws {
        let data = try HAJSON.makeEncoder().encode(Array(entities.values))
        try data.write(to: url, options: .atomic)
    }

    public func loadCache(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let states = try? HAJSON.makeDecoder().decode([EntityState].self, from: data) else { return }
        applySnapshot(states)
    }
}
