import ArgumentParser
import Foundation
import HomeBarCore

@main
struct HomeBarCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "homebarcli",
        abstract: "Debug HomeBar's Home Assistant connection.",
        subcommands: [States.self, Watch.self, Toggle.self, Call.self])
}

struct ConnectOptions: ParsableArguments {
    @Option(help: "HA base URL, e.g. http://homeassistant.local:8123") var url: String?
    @Option(help: "Long-lived access token") var token: String?

    func connectedClient() async throws -> HAClient {
        let env = ProcessInfo.processInfo.environment
        let settings = Settings.load(from: Settings.defaultURL())
        let urlStr = url ?? env["HOMEBAR_URL"] ?? settings.serverURL?.absoluteString
        guard let urlStr, let base = URL(string: urlStr), let ws = haWebSocketURL(from: base)
        else { throw ValidationError("Provide --url or set HOMEBAR_URL") }
        guard let tok = token ?? env["HOMEBAR_TOKEN"] ?? FileTokenStore().read()
        else { throw ValidationError("Provide --token or set HOMEBAR_TOKEN") }
        let client = HAClient(url: ws, token: tok, transport: URLSessionWebSocketTransport(url: ws))
        try await client.connect()
        return client
    }
}

struct States: AsyncParsableCommand {
    @OptionGroup var conn: ConnectOptions
    @Option(help: "Filter by domain, e.g. sensor") var domain: String?
    func run() async throws {
        let client = try await conn.connectedClient()
        let states = try await client.getStates()
            .filter { domain == nil || $0.entityID.hasPrefix("\(domain!).") }
            .sorted { $0.entityID < $1.entityID }
        for s in states { print("\(s.entityID)\t\(s.state)\t\(s.unit ?? "")") }
        await client.disconnect()
    }
}

struct Watch: AsyncParsableCommand {
    @OptionGroup var conn: ConnectOptions
    func run() async throws {
        let client = try await conn.connectedClient()
        try await client.subscribeStateChanges()
        print("Watching state_changed… (Ctrl-C to stop)")
        for await c in client.events {
            print("\(c.entityID)\t→\t\(c.newState?.state ?? "removed")")
        }
    }
}

struct Toggle: AsyncParsableCommand {
    @OptionGroup var conn: ConnectOptions
    @Argument(help: "entity_id, e.g. switch.coffee") var entityID: String
    func run() async throws {
        let client = try await conn.connectedClient()
        try await client.send(HACommand.toggle(entityID))
        print("toggled \(entityID)")
        await client.disconnect()
    }
}

struct Call: AsyncParsableCommand {
    @OptionGroup var conn: ConnectOptions
    @Argument var domain: String
    @Argument var service: String
    @Argument var entityID: String
    @Option(parsing: .upToNextOption, help: "key=value pairs (string values)") var data: [String] = []
    func run() async throws {
        let client = try await conn.connectedClient()
        var payload: [String: JSONValue] = [:]
        for kv in data {
            let parts = kv.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { payload[String(parts[0])] = .string(String(parts[1])) }
        }
        try await client.send(ServiceCall(domain: domain, service: service, data: payload, target: entityID))
        print("called \(domain).\(service) on \(entityID)")
        await client.disconnect()
    }
}
