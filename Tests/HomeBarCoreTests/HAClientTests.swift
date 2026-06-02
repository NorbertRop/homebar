import Testing
import Foundation
@testable import HomeBarCore

private let authRequired = #"{"type":"auth_required","ha_version":"2026.6"}"#
private let authOK = #"{"type":"auth_ok"}"#
private let authInvalid = #"{"type":"auth_invalid","message":"bad"}"#

@Test func authHandshakeSucceeds() async throws {
    let t = FakeWebSocketTransport()
    let client = HAClient(url: URL(string: "ws://h/api/websocket")!, token: "tok", transport: t)
    await t.enqueue(authRequired); await t.enqueue(authOK)
    try await client.connect()
    let sent = await t.sent
    let authJSON = try HAJSON.makeDecoder().decode(JSONValue.self, from: sent[0].data(using: .utf8)!)
    #expect(authJSON["type"]?.stringValue == "auth")
    #expect(authJSON["access_token"]?.stringValue == "tok")
}

@Test func authInvalidThrows() async {
    let t = FakeWebSocketTransport()
    let client = HAClient(url: URL(string: "ws://h")!, token: "tok", transport: t)
    await t.enqueue(authRequired); await t.enqueue(authInvalid)
    await #expect(throws: HAError.authFailed) { try await client.connect() }
}

@Test func getStatesDecodesResult() async throws {
    let t = FakeWebSocketTransport()
    let client = HAClient(url: URL(string: "ws://h")!, token: "tok", transport: t)
    await t.enqueue(authRequired); await t.enqueue(authOK)
    try await client.connect()

    async let statesResult = client.getStates()
    try await Task.sleep(for: .milliseconds(20))
    await t.enqueue(#"{"id":1,"type":"result","success":true,"result":[{"entity_id":"sensor.x","state":"5","attributes":{},"last_changed":"2026-06-02T10:00:00+00:00","last_updated":"2026-06-02T10:00:00+00:00"}]}"#)
    let states = try await statesResult
    #expect(states.count == 1 && states[0].entityID == "sensor.x")
}

@Test func eventsStreamStateChanges() async throws {
    let t = FakeWebSocketTransport()
    let client = HAClient(url: URL(string: "ws://h")!, token: "tok", transport: t)
    await t.enqueue(authRequired); await t.enqueue(authOK)
    try await client.connect()

    var iterator = client.events.makeAsyncIterator()
    await t.enqueue(#"{"id":9,"type":"event","event":{"event_type":"state_changed","data":{"entity_id":"light.x","new_state":{"entity_id":"light.x","state":"on","attributes":{},"last_changed":"2026-06-02T10:00:00+00:00","last_updated":"2026-06-02T10:00:00+00:00"}}}}"#)
    let change = await iterator.next()
    #expect(change?.entityID == "light.x")
    #expect(change?.newState?.state == "on")
}
