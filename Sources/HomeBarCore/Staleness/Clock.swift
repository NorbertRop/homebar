import Foundation

public protocol DateProvider: Sendable { var now: Date { get } }
public struct SystemDateProvider: DateProvider { public init() {}; public var now: Date { Date() } }

public protocol Notifier: Sendable {
    func deviceWentOffline(name: String, entityID: String)
    func deviceRecovered(name: String, entityID: String)
}
