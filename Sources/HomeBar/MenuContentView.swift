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
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()
            if !model.isConfigured {
                onboarding
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !grouped.pinned.isEmpty { section("Pinned", ids: grouped.pinned) }
                        ForEach(grouped.areas, id: \.name) { area in areaView(area) }
                        if !grouped.unassigned.looseEntityIDs.isEmpty || !grouped.unassigned.deviceCards.isEmpty {
                            areaView(grouped.unassigned)
                        }
                        if !automations.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                sectionHeader("Automations")
                                ForEach(automations) { AutomationRow(model: model, entityID: $0.entityID) }
                            }
                        }
                    }.padding(.horizontal, 4)
                }.frame(maxHeight: 460)
            }
            Divider()
            footer
        }
        .padding(10)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Image(systemName: "house"); Text("HomeBar").font(.headline)
            Spacer()
            Circle().frame(width: 7, height: 7)
                .foregroundStyle(model.connection == .authenticated ? .green : .secondary)
            Text(model.connection == .authenticated ? "Connected" : "Offline")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func section(_ title: String, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title)
            ForEach(ids, id: \.self) { EntityRow(model: model, entityID: $0) }
        }
    }

    private func areaView(_ area: AreaSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(area.name)
            ForEach(area.deviceCards, id: \.deviceID) { DeviceCardView(model: model, card: $0) }
            ForEach(area.looseEntityIDs, id: \.self) { EntityRow(model: model, entityID: $0) }
        }
    }

    private var onboarding: some View {
        VStack(spacing: 8) {
            Text("Connect to Home Assistant").font(.headline)
            Text("Add your server URL and a long-lived access token in Settings.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            SettingsLink { Text("Open Settings…") }
        }.padding()
    }

    private var footer: some View {
        HStack {
            if model.offlineCount > 0 {
                Label("\(model.offlineCount) offline", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }
            Spacer()
            SettingsLink { Image(systemName: "gear") }
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
        }
    }
}
