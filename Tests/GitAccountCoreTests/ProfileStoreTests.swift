import XCTest
@testable import GitAccountCore

final class ProfileStoreTests: XCTestCase {
    func testProfileLifecycle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfileStore(url: directory.appendingPathComponent("profiles.json"))
        let profile = Profile(name: "Name", email: "name@example.com", sshKeyPath: "/tmp/key")
        try store.add(id: "one", profile: profile)
        try store.add(id: "two", profile: profile)
        XCTAssertThrowsError(try store.add(id: "one", profile: profile))
        let updated = Profile(name: "New", email: "new@example.com", sshKeyPath: "/tmp/key2")
        try store.add(id: "one", profile: updated, replace: true)
        XCTAssertEqual(try store.profiles()["one"], updated)
        try store.remove(id: "one")
        XCTAssertEqual(try store.profiles(), ["two": profile])
    }

    func testBadDatabaseAndPath() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profiles.json")
        try Data("{\"version\":2,\"profiles\":{}}".utf8).write(to: url)
        XCTAssertThrowsError(try ProfileStore(url: url).profiles())
        XCTAssertEqual(try normalizedKeyPath("key with ' quote", currentDirectory: "/tmp"), "/tmp/key with ' quote")
        XCTAssertThrowsError(try normalizedKeyPath("key%h"))
    }
}
