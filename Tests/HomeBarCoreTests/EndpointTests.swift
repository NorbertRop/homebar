import Testing
import Foundation
@testable import HomeBarCore

@Test func buildsWebSocketURL() {
    #expect(haWebSocketURL(from: URL(string: "http://homeassistant.local:8123")!)?.absoluteString
            == "ws://homeassistant.local:8123/api/websocket")
    #expect(haWebSocketURL(from: URL(string: "https://ha.example.com")!)?.absoluteString
            == "wss://ha.example.com/api/websocket")
}
