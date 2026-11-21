import Foundation
import Darwin

/// Stages edits through Git's own config parser, then publishes them under Git's
/// config.lock protocol. Callers must acquire and verify all semantic preconditions.
public struct GitConfigTransaction {
    public enum Edit {
        case set(String, String)
        case removeAll(String)
    }

    public let configURL: URL
    public let original: Data

    public init(configURL: URL) throws {
        self.configURL = configURL
        do {
            self.original = try Data(contentsOf: configURL)
        } catch {
            throw AccountError.message("Could not read repository config; no changes were made.")
        }
    }

    public func publish(_ edits: [Edit]) throws {
        let fm = FileManager.default
        let directory = configURL.deletingLastPathComponent()
        let temp = directory.appendingPathComponent(".git-account-\(UUID().uuidString)")
        let lock = URL(fileURLWithPath: configURL.path + ".lock")
        var createdTemp = false
        defer {
            if createdTemp { try? fm.removeItem(at: temp) }
        }
        do {
            // This temporary file is independent of the active config.
            let tempFD = open(temp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard tempFD >= 0 else { throw AccountError.message("Could not create temporary config; no changes were made.") }
            close(tempFD)
            createdTemp = true
            try original.write(to: temp)
            for edit in edits {
                let arguments: [String]
                switch edit {
                case let .set(key, value):
                    arguments = ["config", "--file", temp.path, "--replace-all", key, value]
                case let .removeAll(key):
                    arguments = ["config", "--file", temp.path, "--unset-all", key]
                }
                let result = try ProcessRunner().run("/usr/bin/git", arguments)
                switch edit {
                case .removeAll where result.status == 5: break // Key was absent.
                default:
                    guard result.status == 0 else {
                        throw AccountError.message("Could not stage Git configuration; no changes were made.")
                    }
                }
            }
            let staged = try Data(contentsOf: temp)
            let attributes = try fm.attributesOfItem(atPath: configURL.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o600
            let fd = open(lock.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(permissions))
            guard fd >= 0 else {
                throw AccountError.message("Repository config is locked or cannot be locked; no changes were made.")
            }
            var published = false
            defer {
                close(fd)
                if !published { try? fm.removeItem(at: lock) }
            }
            guard try Data(contentsOf: configURL) == original else {
                throw AccountError.message("Repository config changed since preview; no changes were made.")
            }
            guard fchmod(fd, mode_t(permissions)) == 0 else {
                throw AccountError.message("Could not preserve config permissions; no changes were made.")
            }
            try staged.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return }
                var written = 0
                while written < bytes.count {
                    let count = Darwin.write(fd, base.advanced(by: written), bytes.count - written)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw AccountError.message("Could not write config lock; no changes were made.") }
                    written += count
                }
            }
            guard fsync(fd) == 0 else { throw AccountError.message("Could not sync config lock; no changes were made.") }
            guard rename(lock.path, configURL.path) == 0 else {
                throw AccountError.message("Could not publish config; no changes were made.")
            }
            published = true
        } catch let error as AccountError {
            throw error
        } catch {
            throw AccountError.message("Could not prepare repository config; no changes were made.")
        }
    }
}
