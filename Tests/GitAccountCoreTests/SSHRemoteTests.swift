import XCTest
@testable import GitAccountCore

final class SSHRemoteTests: XCTestCase {
    func testSupportedRemotes() {
        XCTAssertEqual(SSHRemote.parse("git@work-alias:org/repo.git"),
                       SSHRemote(host: "work-alias", user: "git", port: nil))
        XCTAssertEqual(SSHRemote.parse("ssh://git@work-alias:2222/org/repo.git"),
                       SSHRemote(host: "work-alias", user: "git", port: 2222))
    }

    func testRejectsUnsupportedAndUnsafeRemotes() {
        for remote in ["https://user:token@example.com/repo", "/tmp/repo", "../repo",
                       "ssh://user:secret@example.com/repo", "-oProxyCommand=x:repo",
                       "ssh://example.com", "example.com:", "a\nb:repo"] {
            XCTAssertNil(SSHRemote.parse(remote), remote)
        }
    }
}
