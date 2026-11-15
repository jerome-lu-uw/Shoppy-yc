import Testing
@testable import ShoppyCore

@Test func rulesVersionIsSet() {
    #expect(!ShoppyCore.rulesVersion.isEmpty)
}
