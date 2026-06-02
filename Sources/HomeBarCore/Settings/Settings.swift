import Foundation

public struct Settings: Sendable, Codable, Equatable {
    public var serverURL: URL?
    public var stalenessWindow: TimeInterval
    public var perEntityWindow: [String: TimeInterval]
    public var pinned: Set<String>
    public var hidden: Set<String>
    public var notifyOffline: Bool

    public init(serverURL: URL? = nil, stalenessWindow: TimeInterval = 900,
                perEntityWindow: [String: TimeInterval] = [:], pinned: Set<String> = [],
                hidden: Set<String> = [], notifyOffline: Bool = true) {
        self.serverURL = serverURL; self.stalenessWindow = stalenessWindow
        self.perEntityWindow = perEntityWindow; self.pinned = pinned
        self.hidden = hidden; self.notifyOffline = notifyOffline
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
