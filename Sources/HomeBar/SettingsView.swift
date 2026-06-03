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

    var body: some View {
        TabView {
            connectionTab.tabItem { Label("Connection", systemImage: "network") }
            favoritesTab.tabItem { Label("Favorites", systemImage: "star") }
            entitiesTab.tabItem { Label("Entities", systemImage: "list.bullet") }
            alertsTab.tabItem { Label("Alerts", systemImage: "bell") }
        }
        .frame(width: 460, height: 420)
        .followsActiveSpace()
        .onAppear {
            urlString = model.settings.serverURL?.absoluteString ?? ""
            token = model.tokenStore.read() ?? ""
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private var connectionTab: some View {
        Form {
            TextField("Server URL", text: $urlString, prompt: Text("http://homeassistant.local:8123"))
            SecureField("Long-lived token", text: $token)
            HStack {
                Button("Test connection") { Task { await test() } }
                Text(testResult).font(.caption).foregroundStyle(.secondary)
            }
            Button("Save") {
                model.settings.serverURL = URL(string: urlString)
                try? model.tokenStore.write(token)
                model.saveSettings()
                model.restart()
            }.keyboardShortcut(.defaultAction)

            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        launchAtLogin = on
                    } catch {
                        launchAtLogin = (SMAppService.mainApp.status == .enabled)
                    }
                }))

            Picker("Menu bar shows", selection: Binding(
                get: { model.settings.menuBarEntityID },
                set: { model.settings.menuBarEntityID = $0; model.saveSettings() })) {
                Text("Icon only").tag(String?.none)
                ForEach(menuBarCandidates, id: \.entityID) { s in
                    Text(s.friendlyName).tag(String?.some(s.entityID))
                }
            }
        }.padding()
    }

    /// Numeric sensors offered for the menu-bar readout.
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

    private var entitiesTab: some View {
        VStack {
            TextField("Search", text: $search)
            List(filteredEntities, id: \.entityID) { s in
                HStack {
                    Text(s.friendlyName)
                    Text(s.entityID).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Pin", isOn: Binding(
                        get: { model.isPinned(s.entityID) },
                        set: { _ in model.togglePin(s.entityID) })).toggleStyle(.button)
                    Toggle("Hide", isOn: binding(in: \.hidden, id: s.entityID)).toggleStyle(.button)
                }
            }
        }.padding()
    }

    private var favoritesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drag to reorder. Favorites appear at the top of the menu, in this order.")
                .font(.caption).foregroundStyle(.secondary)
            if model.settings.pinned.isEmpty {
                Spacer()
                Text("No favorites yet.\nRight-click any entity in the menu → Pin.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(model.settings.pinned, id: \.self) { id in
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            Text(model.entity(id)?.friendlyName ?? id).lineLimit(1)
                            Spacer()
                            Button { model.togglePin(id) } label: { Image(systemName: "pin.slash") }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                    }
                    .onMove { model.moveFavorites(from: $0, to: $1) }
                }
            }
        }.padding()
    }

    private var filteredEntities: [EntityState] {
        model.store.entities.values
            .filter { search.isEmpty || $0.friendlyName.localizedCaseInsensitiveContains(search)
                      || $0.entityID.localizedCaseInsensitiveContains(search) }
            .sorted { $0.entityID < $1.entityID }
    }

    private func binding(in keyPath: WritableKeyPath<HomeBarCore.Settings, Set<String>>, id: String) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath].contains(id) },
            set: { on in
                if on { model.settings[keyPath: keyPath].insert(id) }
                else { model.settings[keyPath: keyPath].remove(id) }
                model.saveSettings()
            })
    }

    private var alertsTab: some View {
        Form {
            Toggle("Show offline / unavailable devices in the menu", isOn: Binding(
                get: { !model.settings.hideOffline },
                set: { model.settings.hideOffline = !$0; model.saveSettings() }))
            Toggle("Show diagnostic / advanced entities", isOn: Binding(
                get: { model.settings.showDiagnostic },
                set: { model.settings.showDiagnostic = $0; model.saveSettings() }))
            Toggle("Notify when a device goes offline/stale", isOn: $model.settings.notifyOffline)
                .onChange(of: model.settings.notifyOffline) { model.saveSettings() }
            HStack {
                Text("Stale after")
                TextField("minutes", value: Binding(
                    get: { model.settings.stalenessWindow / 60 },
                    set: { model.settings.stalenessWindow = $0 * 60; model.saveSettings() }
                ), format: .number).frame(width: 60)
                Text("minutes")
            }
        }.padding()
    }
}
