import Foundation

public struct Profile: Codable, Equatable {
    public let name: String
    public let email: String
    public let sshKeyPath: String

    public init(name: String, email: String, sshKeyPath: String) {
        self.name = name
        self.email = email
        self.sshKeyPath = sshKeyPath
    }
}

public enum AccountError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        if case let .message(message) = self { return message }
        return nil
    }
}

private struct Database: Codable {
    var version: Int = 1
    var profiles: [String: Profile] = [:]
}

public struct ProfileStore {
    public let url: URL
    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/git-account/profiles.json")
    }

    private func load() throws -> Database {
        guard FileManager.default.fileExists(atPath: url.path) else { return Database() }
        do {
            let db = try JSONDecoder().decode(Database.self, from: Data(contentsOf: url))
            guard db.version == 1 else { throw AccountError.message("Unsupported profile database version: \(db.version).") }
            return db
        } catch let error as AccountError { throw error }
        catch { throw AccountError.message("Could not read profile database: \(error.localizedDescription)") }
    }

    public func profiles() throws -> [String: Profile] { try load().profiles }

    public func add(id: String, profile: Profile, replace: Bool = false) throws {
        guard id.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil else {
            throw AccountError.message("Profile ID must contain lowercase ASCII letters, digits, or hyphens and start with a letter or digit.")
        }
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountError.message("Name and email must not be empty.")
        }
        var db = try load()
        guard replace || db.profiles[id] == nil else { throw AccountError.message("Profile already exists; use --replace to update it.") }
        db.profiles[id] = profile
        try save(db)
    }

    public func remove(id: String) throws {
        var db = try load()
        guard db.profiles.removeValue(forKey: id) != nil else { throw AccountError.message("Profile not found: \(id)") }
        try save(db)
    }

    private func save(_ db: Database) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(db).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

public func normalizedKeyPath(_ path: String, currentDirectory: String = FileManager.default.currentDirectoryPath) throws -> String {
    guard !path.isEmpty, path.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
          !path.contains("%"), !path.contains("$") else {
        throw AccountError.message("SSH key path is empty or contains unsupported expansion or control characters.")
    }
    let expanded = (path as NSString).expandingTildeInPath
    guard path == expanded || path.hasPrefix("~/") else { throw AccountError.message("Only ~/ home expansion is supported.") }
    let absolute = expanded.hasPrefix("/") ? expanded : (currentDirectory as NSString).appendingPathComponent(expanded)
    return URL(fileURLWithPath: absolute).standardizedFileURL.path
}
