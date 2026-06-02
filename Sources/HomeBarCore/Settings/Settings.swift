import Foundation

public struct Settings: Sendable, Codable, Equatable {
    public var serverURL: URL?
    public var stalenessWindow: TimeInterval
    public var perEntityWindow: [String: TimeInterval]
    public var pinned: [String]   // ordered — the user's favorites order
    public var hidden: Set<String>
    public var order: [String]    // custom order for non-pinned entities, within their list
    public var notifyOffline: Bool
    public var hideOffline: Bool
    public var showDiagnostic: Bool
    public var menuBarEntityID: String?   // entity whose value shows in the menu bar (nil = icon only)

    public init(serverURL: URL? = nil, stalenessWindow: TimeInterval = 900,
                perEntityWindow: [String: TimeInterval] = [:], pinned: [String] = [],
                hidden: Set<String> = [], notifyOffline: Bool = true, hideOffline: Bool = true,
                showDiagnostic: Bool = false, order: [String] = [], menuBarEntityID: String? = nil) {
        self.serverURL = serverURL; self.stalenessWindow = stalenessWindow
        self.perEntityWindow = perEntityWindow; self.pinned = pinned
        self.hidden = hidden; self.notifyOffline = notifyOffline; self.hideOffline = hideOffline
        self.showDiagnostic = showDiagnostic; self.order = order
        self.menuBarEntityID = menuBarEntityID
    }

    enum CodingKeys: String, CodingKey {
        case serverURL, stalenessWindow, perEntityWindow, pinned, hidden, notifyOffline, hideOffline, showDiagnostic, order, menuBarEntityID
    }

    /// Forgiving decoder: missing keys fall back to defaults, so settings files
    /// written by an older build keep loading as the schema grows.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        serverURL = try c.decodeIfPresent(URL.self, forKey: .serverURL) ?? d.serverURL
        stalenessWindow = try c.decodeIfPresent(TimeInterval.self, forKey: .stalenessWindow) ?? d.stalenessWindow
        perEntityWindow = try c.decodeIfPresent([String: TimeInterval].self, forKey: .perEntityWindow) ?? d.perEntityWindow
        pinned = try c.decodeIfPresent([String].self, forKey: .pinned) ?? d.pinned
        hidden = try c.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? d.hidden
        notifyOffline = try c.decodeIfPresent(Bool.self, forKey: .notifyOffline) ?? d.notifyOffline
        hideOffline = try c.decodeIfPresent(Bool.self, forKey: .hideOffline) ?? d.hideOffline
        showDiagnostic = try c.decodeIfPresent(Bool.self, forKey: .showDiagnostic) ?? d.showDiagnostic
        order = try c.decodeIfPresent([String].self, forKey: .order) ?? d.order
        menuBarEntityID = try c.decodeIfPresent(String.self, forKey: .menuBarEntityID) ?? d.menuBarEntityID
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("settings.json")
    }

    public static func load(from url: URL) -> Settings {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    public func save(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
