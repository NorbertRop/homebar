import Testing
@testable import HomeBarCore

@Test func versionIsSet() {
    #expect(HomeBarBuildInfo.version == "0.1.0")
}
