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

/// Interactive domains. These are kept OUT of device cards so they can cluster as
/// "controls", separate from the device's sensor readings.
public let controlDomains: Set<String> = [
    "light", "switch", "climate", "vacuum", "fan", "cover", "lock", "media_player",
    "humidifier", "water_heater",
]

public func isControlDomain(_ entityID: String) -> Bool {
    controlDomains.contains(String(entityID.split(separator: ".").first ?? ""))
}

/// Sort `ids` by a user-defined `order`: ids present in `order` come first, in that
/// sequence; the rest keep their incoming order.
public func ordered(_ ids: [String], by order: [String]) -> [String] {
    let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
    return ids.enumerated().sorted { a, b in
        switch (rank[a.element], rank[b.element]) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.offset < b.offset
        }
    }.map(\.element)
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

/// Whether an entity shows in the menu, or is hidden and why.
public enum EntityVisibility: Sendable, Equatable {
    case shown
    case hidden(HideReason)
}

public enum HideReason: String, Sendable, Equatable {
    case manual, deviceOffline, offline, diagnostic, domain
    /// Short, user-facing badge text.
    public var label: String {
        switch self {
        case .manual: "Hidden"
        case .deviceOffline: "Device offline"
        case .offline: "Offline"
        case .diagnostic: "Diagnostic"
        case .domain: "Filtered"
        }
    }
}

/// Devices whose connectivity sensor reports disconnected — hidden wholesale while offline-hiding
/// is on, since their controls won't respond anyway.
public func disconnectedDeviceIDs(_ entities: [EntityState], registry: Registry, settings: Settings) -> Set<String> {
    guard settings.hideOffline else { return [] }
    return Set(entities
        .filter { $0.deviceClass == "connectivity" && $0.state == "off" }
        .compactMap { registry.deviceID(for: $0.entityID) })
}

/// The single source of truth for the menu's filtering — also used by the Entities settings list
/// to annotate what's hidden and why.
public func entityVisibility(_ entity: EntityState, registry: Registry, settings: Settings,
                             disconnectedDevices: Set<String>) -> EntityVisibility {
    if settings.hidden.contains(entity.entityID) { return .hidden(.manual) }
    if settings.pinned.contains(entity.entityID) { return .shown }   // pinned always shows
    if settings.shown.contains(entity.entityID) { return .shown }    // user force-showed it
    if let did = registry.deviceID(for: entity.entityID), disconnectedDevices.contains(did) { return .hidden(.deviceOffline) }
    if !isUsefulDomain(entity.entityID) { return .hidden(.domain) }                          // noise domains
    if !settings.showDiagnostic && registry.isDiagnostic(entity.entityID) { return .hidden(.diagnostic) }
    if settings.hideOffline && !entity.isAvailable { return .hidden(.offline) }
    return .shown
}

/// `entities` should exclude automations (the UI lists those separately).
public func groupEntities(_ entities: [EntityState], registry: Registry,
                          settings: Settings) -> GroupedEntities {
    let disconnectedDevices = disconnectedDeviceIDs(entities, registry: registry, settings: settings)
    let visible = entities.filter {
        entityVisibility($0, registry: registry, settings: settings, disconnectedDevices: disconnectedDevices) == .shown
    }
    let visibleIDs = Set(visible.map(\.entityID))
    let pinnedIDs = settings.pinned.filter { visibleIDs.contains($0) }   // keep the user's order

    var byArea: [String: [EntityState]] = [:]
    for e in visible where !settings.pinned.contains(e.entityID) {
        let area = registry.areaName(for: e.entityID) ?? "Unassigned"
        byArea[area, default: []].append(e)
    }

    func section(name: String, _ items: [EntityState]) -> AreaSection {
        var byDevice: [String: [EntityState]] = [:]
        var loose: [EntityState] = []
        for e in items {
            if isControlDomain(e.entityID) { loose.append(e) }   // controls never go in a sensor card
            else if let did = registry.deviceID(for: e.entityID) { byDevice[did, default: []].append(e) }
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
