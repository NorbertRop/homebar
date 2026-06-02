import SwiftUI
import AppKit
import HomeBarCore

struct MenuContentView: View {
    @Bindable var model: AppModel

    private var grouped: GroupedEntities {
        let nonAutomation = model.store.entities.values.filter { $0.domain != .automation }
        return groupEntities(Array(nonAutomation), registry: model.store.registry, settings: model.settings)
    }
    private var automations: [EntityState] {
        model.store.entities.values.filter { $0.domain == .automation && !model.settings.hidden.contains($0.entityID) }
            .sorted { $0.friendlyName < $1.friendlyName }
    }

    var body: some View {
        let _ = model.dataVersion   // re-render when entity data changes (see AppModel.dataVersion)
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()
            if !model.isConfigured {
                onboarding
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !grouped.pinned.isEmpty { section("Pinned", ids: grouped.pinned) }
                        ForEach(grouped.areas, id: \.name) { area in areaView(area) }
                        if !grouped.unassigned.looseEntityIDs.isEmpty || !grouped.unassigned.deviceCards.isEmpty {
                            areaView(grouped.unassigned)
                        }
                        if !automations.isEmpty {
                            let autoIDs = ordered(automations.map(\.entityID), by: model.settings.order)
                            VStack(alignment: .leading, spacing: 2) {
                                sectionHeader("Automations")
                                ForEach(autoIDs, id: \.self) { AutomationRow(model: model, entityID: $0, siblings: autoIDs) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                }
                .frame(height: 420)
            }
            Divider()
            footer
        }
        .padding(10)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "house.fill").foregroundStyle(.tint)
            Text("HomeBar").font(.headline)
            Spacer()
            Circle().frame(width: 6, height: 6)
                .foregroundStyle(model.connection == .authenticated ? .green : .orange)
            Text(model.connection == .authenticated ? "Connected" : "Reconnecting…")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2).fontWeight(.semibold).kerning(0.5)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6).padding(.top, 2)
    }

    private func section(_ title: String, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title)
            ForEach(ids, id: \.self) { EntityRow(model: model, entityID: $0, siblings: ids) }
        }
    }

    private func areaView(_ area: AreaSection) -> some View {
        // Controls cluster (with breathing room) → sensor device-cards → loose readings.
        let controls = ordered(area.looseEntityIDs.filter { isControlDomain($0) }.sorted(), by: model.settings.order)
        let readings = ordered(area.looseEntityIDs.filter { !isControlDomain($0) }.sorted(), by: model.settings.order)
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader(area.name)
            if !controls.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(controls, id: \.self) { EntityRow(model: model, entityID: $0, siblings: controls) }
                }
            }
            ForEach(area.deviceCards, id: \.deviceID) { DeviceCardView(model: model, card: $0) }
            ForEach(readings, id: \.self) { EntityRow(model: model, entityID: $0, siblings: readings) }
        }
    }

    private var onboarding: some View {
        VStack(spacing: 8) {
            Text("Connect to Home Assistant").font(.headline)
            Text("Add your server URL and a long-lived access token in Settings.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            SettingsLink { Text("Open Settings…") }
        }.padding().frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.offlineCount > 0 {
                Label("\(model.offlineCount) offline", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Spacer()
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}
