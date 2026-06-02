import Testing
import Foundation
@testable import HomeBarCore

@Test func decodesHeterogeneousObject() throws {
    let json = #"{"a": 1, "b": 2.5, "c": "x", "d": true, "e": [1,2], "f": null}"#.data(using: .utf8)!
    let v = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(v["a"]?.intValue == 1)
    #expect(v["b"]?.doubleValue == 2.5)
    #expect(v["c"]?.stringValue == "x")
    #expect(v["d"]?.boolValue == true)
    #expect(v["e"]?.arrayValue?.count == 2)
    #expect(v["f"]?.isNull == true)
}

@Test func parsesHADateWithFractionalSecondsAndZone() throws {
    let fmt = HAJSON.makeDecoder()
    struct Box: Decodable { let t: Date }
    let data = #"{"t": "2026-06-02T10:11:12.345678+00:00"}"#.data(using: .utf8)!
    let box = try fmt.decode(Box.self, from: data)
    #expect(abs(box.t.timeIntervalSince1970 - 1780395072.345678) < 0.01)
}

@Test func coercedStringStringifiesScalars() {
    #expect(JSONValue.int(3).coercedString == "3")
    #expect(JSONValue.double(2.5).coercedString == "2.5")
    #expect(JSONValue.string("x").coercedString == "x")
    #expect(JSONValue.bool(true).coercedString == "true")
    #expect(JSONValue.null.coercedString == nil)
    #expect(JSONValue.array([]).coercedString == nil)
}
