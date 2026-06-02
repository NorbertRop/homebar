import Foundation

public struct DeviceCard: Sendable, Equatable {
    public let deviceID: String
    public let name: String
    public let entityIDs: [String]
}

public struct AreaSection: Sendable, Equatable {
    public let name: String
    public let deviceCards: [DeviceCard]
    public let looseEntityIDs: [String]
}

public struct GroupedEntities: Sendable, Equatable {
    public let pinned: [String]
    public let areas: [AreaSection]
    public let unassigned: AreaSection
}

/// `entities` should exclude automations (the UI lists those separately).
public func groupEntities(_ entities: [EntityState], registry: Registry,
                          settings: Settings) -> GroupedEntities {
    let visible = entities.filter { !settings.hidden.contains($0.entityID) }
    let pinnedIDs = visible.map(\.entityID).filter { settings.pinned.contains($0) }.sorted()

    var byArea: [String: [EntityState]] = [:]
    for e in visible where !settings.pinned.contains(e.entityID) {
        let area = registry.areaName(for: e.entityID) ?? "Unassigned"
        byArea[area, default: []].append(e)
    }

    func section(name: String, _ items: [EntityState]) -> AreaSection {
        var byDevice: [String: [EntityState]] = [:]
        var loose: [EntityState] = []
        for e in items {
            if let did = registry.deviceID(for: e.entityID) { byDevice[did, default: []].append(e) }
            else { loose.append(e) }
        }
        var cards: [DeviceCard] = []
        for (did, members) in byDevice {
            if members.count >= 2 {
                cards.append(DeviceCard(deviceID: did,
                                        name: registry.deviceName(for: members[0].entityID) ?? did,
                                        entityIDs: members.map(\.entityID).sorted()))
            } else { loose.append(contentsOf: members) }
        }
        return AreaSection(name: name,
                           deviceCards: cards.sorted { $0.name < $1.name },
                           looseEntityIDs: loose.map(\.entityID).sorted())
    }

    let areaSections = byArea.keys.filter { $0 != "Unassigned" }.sorted()
        .map { section(name: $0, byArea[$0]!) }
    let unassigned = section(name: "Unassigned", byArea["Unassigned"] ?? [])
    return GroupedEntities(pinned: pinnedIDs, areas: areaSections, unassigned: unassigned)
}
