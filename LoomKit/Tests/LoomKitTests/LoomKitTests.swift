import Testing
@testable import LoomKit

@Suite("LoomKit")
struct LoomKitTests {
    @Test("Package builds")
    func packageBuilds() {
        #expect(true)
    }
}
