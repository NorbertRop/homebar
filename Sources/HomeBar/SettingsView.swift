import SwiftUI
import HomeBarCore
import ServiceManagement

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var urlString: String = ""
    @State private var token: String = ""
    @State private var testResult: String = ""
    @State private var search: String = ""
    @State private var launchAtLogin = false
    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                ForEach(Tab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.icon).font(.system(size: 18)).frame(height: 20)
                            Text(t.title).font(.caption)
                        }
                        .frame(width: 74, height: 50)
                        .foregroundStyle(tab == t ? Color.accentColor : Color.secondary)
                        .background(tab == t ? Color.accentColor.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: settingsWindowSize.width, height: settingsWindowSize.height)
        .onAppear {
            urlString = model.settings.serverURL?.absoluteString ?? ""
            token = model.tokenStore.read() ?? ""
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .general: generalTab
        case .connection: connectionTab
        case .pinned: pinnedTab
        case .entities: entitiesTab
        case .alerts: alertsTab
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Menu Bar") {
                Picker("Show", selection: Binding(
                    get: { model.settings.menuBarEntityID },
                    set: { model.settings.menuBarEntityID = $0; model.saveSettings() })) {
                    Text("Icon only").tag(String?.none)
                    ForEach(menuBarCandidates, id: \.entityID) { s in
                        Text(s.friendlyName).tag(String?.some(s.entityID))
                    }
                }
            }
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            launchAtLogin = on
                        } catch { launchAtLogin = (SMAppService.mainApp.status == .enabled) }
                    }))
            }
            Section("Updates") {
                LabeledContent("Current version", value: appVersion)
                Button("Check for Updates…") { model.checkForUpdates?() }
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    // MARK: - Connection

    private var connectionTab: some View {
        Form {
            Section("Home Assistant") {
                TextField("Server URL", text: $urlString, prompt: Text("http://homeassistant.local:8123"))
                SecureField("Long-lived token", text: $token)
                HStack {
                    Button("Test Connection") { Task { await test() } }
                    if !testResult.isEmpty {
                        Text(testResult).font(.caption).lineLimit(1)
                            .foregroundStyle(testResult.hasPrefix("OK") ? Color.green : Color.secondary)
                    }
                    Spacer()
                    Button("Save") {
                        model.settings.serverURL = URL(string: urlString)
                        try? model.tokenStore.write(token)
                        model.saveSettings()
                        model.restart()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Pinned

    private var pinnedTab: some View {
        Group {
            if model.settings.pinned.isEmpty {
                emptyState(icon: "pin", title: "No pinned items yet",
                           detail: "Right-click any entity in the menu → Pin.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Drag to reorder — pinned items appear at the top of the menu.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                    List {
                        ForEach(model.settings.pinned, id: \.self) { id in
                            HStack(spacing: 10) {
                                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                                Text(model.entity(id)?.friendlyName ?? id).lineLimit(1)
                                Spacer()
                                Button { model.togglePin(id) } label: { Image(systemName: "pin.slash") }
                                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Unpin")
                            }
                        }
                        .onMove { model.moveFavorites(from: $0, to: $1) }
                    }
                }
            }
        }
    }

    // MARK: - Entities

    private var entitiesTab: some View {
        let disconnected = disconnectedDeviceIDs(Array(model.store.entities.values),
                                                 registry: model.store.registry, settings: model.settings)
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search entities", text: $search).textFieldStyle(.plain)
            }
            .padding(7).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16).padding(.vertical, 10)
            List(filteredEntities, id: \.entityID) { entityRow($0, disconnected: disconnected) }
        }
    }

    @ViewBuilder private func entityRow(_ s: EntityState, disconnected: Set<String>) -> some View {
        let vis = entityVisibility(s, registry: model.store.registry, settings: model.settings,
                                   disconnectedDevices: disconnected)
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(s.friendlyName).lineLimit(1)
                Text(s.entityID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            // Why it's auto-hidden (a manual hide is already conveyed by the Hide button being on).
            if case .hidden(let reason) = vis, reason != .manual {
                let warn = reason == .offline || reason == .deviceOffline
                Text(reason.label).font(.caption2).fontWeight(.medium)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(warn ? Color.orange : Color.secondary)
                    .background((warn ? Color.orange : Color.secondary).opacity(0.15), in: Capsule())
            }
            Spacer(minLength: 8)
            pillToggle("Pin", on: model.isPinned(s.entityID)) { model.togglePin(s.entityID) }
            pillToggle("Hide", on: vis != .shown) { setHide(s, vis == .shown, disconnected) }
        }
    }

    /// A small on/off pill with explicit colors, so the "on" state stays visible even when the
    /// window is inactive (a `.button` toggle desaturates its accent on focus loss).
    private func pillToggle(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption).fontWeight(.medium)
                .foregroundStyle(on ? Color.white : Color.secondary)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(on ? Color.accentColor : Color.secondary.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Hide reflects effective visibility; turning it off force-shows an auto-hidden entity.
    private func setHide(_ s: EntityState, _ hide: Bool, _ disconnected: Set<String>) {
        let id = s.entityID
        if hide {
            model.settings.shown.remove(id)
            model.settings.pinned.removeAll { $0 == id }
            model.settings.hidden.insert(id)
        } else {
            model.settings.hidden.remove(id)
            model.settings.shown.remove(id)
            if entityVisibility(s, registry: model.store.registry, settings: model.settings,
                                disconnectedDevices: disconnected) != .shown {
                model.settings.shown.insert(id)            // still hidden by a rule → force-show
            }
        }
        model.saveSettings()
    }

    // MARK: - Alerts

    private var alertsTab: some View {
        Form {
            Section("Menu") {
                Toggle("Show offline / unavailable devices", isOn: Binding(
                    get: { !model.settings.hideOffline },
                    set: { model.settings.hideOffline = !$0; model.saveSettings() }))
                Toggle("Show diagnostic / advanced entities", isOn: Binding(
                    get: { model.settings.showDiagnostic },
                    set: { model.settings.showDiagnostic = $0; model.saveSettings() }))
            }
            Section("Notifications") {
                Toggle("Notify when a pinned device goes offline or stale", isOn: $model.settings.notifyOffline)
                    .onChange(of: model.settings.notifyOffline) { model.saveSettings() }
                HStack {
                    Text("Consider stale after")
                    Spacer()
                    TextField("", value: Binding(
                        get: { model.settings.stalenessWindow / 60 },
                        set: { model.settings.stalenessWindow = $0 * 60; model.saveSettings() }
                    ), format: .number).frame(width: 50).multilineTextAlignment(.trailing)
                    Text("min").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(.tertiary)
            Text(title).font(.headline).foregroundStyle(.secondary)
            Text(detail).font(.callout).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var menuBarCandidates: [EntityState] {
        model.store.entities.values
            .filter { $0.domain == .sensor && Double($0.state) != nil }
            .sorted { $0.friendlyName < $1.friendlyName }
    }

    private func test() async {
        guard let base = URL(string: urlString), let ws = haWebSocketURL(from: base) else {
            testResult = "Bad URL"; return
        }
        do {
            let c = HAClient(url: ws, token: token, transport: URLSessionWebSocketTransport(url: ws))
            try await c.connect()
            let n = try await c.getStates().count
            await c.disconnect()
            testResult = "OK — \(n) entities"
        } catch { testResult = "Failed: \(error)" }
    }

    private var filteredEntities: [EntityState] {
        model.store.entities.values
            .filter { search.isEmpty || $0.friendlyName.localizedCaseInsensitiveContains(search)
                      || $0.entityID.localizedCaseInsensitiveContains(search) }
            .sorted { $0.entityID < $1.entityID }
    }


    private enum Tab: String, CaseIterable, Identifiable {
        case general, connection, pinned, entities, alerts
        var id: Self { self }
        var title: String {
            switch self {
            case .general: "General"
            case .connection: "Connection"
            case .pinned: "Pinned"
            case .entities: "Entities"
            case .alerts: "Alerts"
            }
        }
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .connection: "network"
            case .pinned: "pin"
            case .entities: "list.bullet"
            case .alerts: "bell"
            }
        }
    }
}
