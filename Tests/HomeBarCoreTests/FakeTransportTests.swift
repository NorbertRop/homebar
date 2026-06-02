import Testing
@testable import HomeBarCore

@Test func fakeCapturesSentAndDeliversEnqueued() async throws {
    let t = FakeWebSocketTransport()
    try await t.connect()
    try await t.send("hello")
    await t.enqueue("world")
    let got = try await t.receive()
    #expect(got == "world")
    #expect(await t.sent == ["hello"])
    #expect(await t.didConnect == true)
}
