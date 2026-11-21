import XCTest
@testable import GitAccountCore

final class SSHCommandTests: XCTestCase {
    func testShellQuotingPreservesPath() throws {
        let path = "/tmp/key with 'apostrophe"
        let command = try SSHCommand.make(keyPath: path)
        XCTAssertTrue(command.contains("'/tmp/key with '\\''apostrophe'"))
        XCTAssertTrue(command.contains("-S none"))
        // Evaluate just the encoded shell argument; the production command is
        // passed to Git, and does not invoke a shell directly.
        let quoted = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let result = try ProcessRunner().run("/bin/sh", ["-c", "printf %s \(quoted)"])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output, path)
    }

    func testRejectsUnsupportedPaths() {
        XCTAssertThrowsError(try SSHCommand.make(keyPath: "relative"))
        XCTAssertThrowsError(try SSHCommand.make(keyPath: "/tmp/%h"))
        XCTAssertThrowsError(try SSHCommand.make(keyPath: "/tmp/$HOME"))
        XCTAssertThrowsError(try SSHCommand.make(keyPath: "/tmp/a\nb"))
        XCTAssertThrowsError(try SSHCommand.validateKeyFile("/definitely/not/a/key"))
    }
}
