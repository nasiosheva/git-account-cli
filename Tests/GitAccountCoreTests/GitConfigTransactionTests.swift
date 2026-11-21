import XCTest
@testable import GitAccountCore

final class GitConfigTransactionTests: XCTestCase {
    func testPublishPreservesUnrelatedConfiguration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = directory.appendingPathComponent("config")
        try Data("[user]\n\tname = Old\n[other]\n\tvalue = preserved\n".utf8).write(to: config)
        let transaction = try GitConfigTransaction(configURL: config)
        try transaction.publish([.set("user.name", "New"), .set("user.email", "new@example.com")])
        let content = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(content.contains("New"))
        XCTAssertTrue(content.contains("preserved"))
        XCTAssertTrue(content.contains("new@example.com"))
    }

    func testConflictAndLockNeverOverwriteChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = directory.appendingPathComponent("config")
        let initial = Data("[user]\n\tname = Old\n".utf8)
        try initial.write(to: config)
        let transaction = try GitConfigTransaction(configURL: config)
        let changed = Data("[user]\n\tname = External\n".utf8)
        try changed.write(to: config)
        XCTAssertThrowsError(try transaction.publish([.set("user.name", "New")]))
        XCTAssertEqual(try Data(contentsOf: config), changed)
        let locked = try GitConfigTransaction(configURL: config)
        let lock = URL(fileURLWithPath: config.path + ".lock")
        try Data("other process".utf8).write(to: lock)
        XCTAssertThrowsError(try locked.publish([.set("user.name", "New")]))
        XCTAssertEqual(try Data(contentsOf: config), changed)
        XCTAssertEqual(try String(contentsOf: lock, encoding: .utf8), "other process")
    }
}
