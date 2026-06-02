import Foundation

public func haWebSocketURL(from base: URL) -> URL? {
    guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
    switch comps.scheme {
    case "https": comps.scheme = "wss"
    case "wss", "ws": break
    default: comps.scheme = "ws"
    }
    let path = comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path
    comps.path = path + "/api/websocket"
    return comps.url
}
