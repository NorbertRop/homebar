import Foundation

/// Domains worth showing in a glanceable dashboard. Everything else (update, button,
/// device_tracker, number, select, conversation, tts/stt, …) is hidden by default
/// unless the user pins it.
public let usefulDomains: Set<String> = [
    "sensor", "binary_sensor", "switch", "light", "climate",
    "fan", "cover", "lock", "media_player", "vacuum", "humidifier", "water_heater",
]

public func isUsefulDomain(_ entityID: String) -> Bool {
    usefulDomains.contains(String(entityID.split(separator: ".").first ?? ""))
}

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
    let visible = entities.filter { e in
        if settings.hidden.contains(e.entityID) { return false }
        if settings.pinned.contains(e.entityID) { return true }   // pinned always shows
        if !isUsefulDomain(e.entityID) { return false }           // hide noise domains
        if !settings.showDiagnostic && registry.isDiagnostic(e.entityID) { return false } // hide diagnostic/config
        if settings.hideOffline && !e.isAvailable { return false } // hide offline by default
        return true
    }
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
