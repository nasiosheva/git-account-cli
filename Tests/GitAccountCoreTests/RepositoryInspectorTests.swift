import XCTest
@testable import GitAccountCore

final class RepositoryInspectorTests: XCTestCase {
    func testRemoteRedaction() {
        XCTAssertEqual(redactRemote("https://user:secret@example.com/org/repo?token=secret"), "https://example.com/…")
        XCTAssertEqual(redactRemote("git@example.com:org/repo"), "example.com:…")
        XCTAssertEqual(redactRemote("/tmp/repo"), "(local or unsupported remote)")
    }

    func testProcessRunnerSeparatesArguments() throws {
        let result = try ProcessRunner().run("/usr/bin/printf", ["%s", "a b'c"])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output, "a b'c")
    }
}
