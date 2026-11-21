import XCTest
@testable import GitAccountCore

final class SSHConfigInspectorTests: XCTestCase {
    func testEffectiveConfigConflicts() throws {
        let valid = "identitiesonly yes\ncontrolpath none\nidentityfile /tmp/key\n"
        XCTAssertNoThrow(try SSHConfigInspector.validateEffectiveConfig(valid, keyPath: "/tmp/key"))
        XCTAssertThrowsError(try SSHConfigInspector.validateEffectiveConfig(valid + "identityfile /tmp/other\n", keyPath: "/tmp/key"))
        XCTAssertThrowsError(try SSHConfigInspector.validateEffectiveConfig(valid + "certificatefile /tmp/cert\n", keyPath: "/tmp/key"))
        XCTAssertThrowsError(try SSHConfigInspector.validateEffectiveConfig("identityfile /tmp/key\n", keyPath: "/tmp/key"))
    }
}
