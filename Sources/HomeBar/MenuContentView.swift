import SwiftUI
import AppKit
import HomeBarCore

struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    /// Show the Settings window — managed by the app delegate so it lands on the current Space.
    private func showSettings() { model.presentSettings?() }

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
                searchField
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if search.isEmpty { groupedContent } else { searchContent }
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

    @ViewBuilder private var groupedContent: some View {
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

    @ViewBuilder private var searchContent: some View {
        let results = visibleIDs.filter(matchesSearch)
        if results.isEmpty {
            Text("No matches for “\(search)”")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
        } else {
            ForEach(results, id: \.self) { id in
                if model.entity(id)?.domain == .automation {
                    AutomationRow(model: model, entityID: id, siblings: results)
                } else {
                    EntityRow(model: model, entityID: id, siblings: results)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 2)
        .onAppear { searchFocused = true }
    }

    /// Every entity currently visible in the menu (respecting hide/offline/diagnostic rules), de-duped.
    private var visibleIDs: [String] {
        let g = grouped
        var ids = g.pinned
        for a in g.areas { ids += a.looseEntityIDs + a.deviceCards.flatMap(\.entityIDs) }
        ids += g.unassigned.looseEntityIDs + g.unassigned.deviceCards.flatMap(\.entityIDs)
        ids += automations.map(\.entityID)
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func matchesSearch(_ id: String) -> Bool {
        guard let e = model.entity(id) else { return false }
        return e.friendlyName.localizedCaseInsensitiveContains(search)
            || id.localizedCaseInsensitiveContains(search)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "house.fill").foregroundStyle(.tint)
            Text("HomeBar").font(.headline)
            Spacer()
            Circle().frame(width: 6, height: 6).foregroundStyle(statusColor)
            Text(statusText).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var statusColor: Color {
        switch model.connection {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .authFailed: .red
        }
    }
    private var statusText: String {
        switch model.connection {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .authFailed: "Auth failed — check token"
        }
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
            Button("Open Settings…") { showSettings() }
        }.padding().frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.offlineCount > 0 {
                Label("\(model.offlineCount) offline", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Spacer()
            Button { model.checkForUpdates?() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Check for Updates…")
            Button { showSettings() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Settings")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Quit HomeBar")
        }
        .padding(.horizontal, 4)
    }
}
