import Foundation

public struct ProcessResult {
    public let status: Int32
    public let output: String
}

public struct ProcessRunner {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], directory: URL? = nil) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let output = Pipe()
        process.standardOutput = output
        // Never forward subprocess diagnostics: URLs and environment values can contain credentials.
        process.standardError = FileHandle.nullDevice
        do { try process.run() }
        catch { throw AccountError.message("Could not start \(URL(fileURLWithPath: executable).lastPathComponent).") }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ProcessResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

public struct RepositoryInspector {
    private let runner = ProcessRunner()
    public let root: URL

    public init() throws {
        let result = try runner.run("/usr/bin/git", ["rev-parse", "--show-toplevel"])
        guard result.status == 0, !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountError.message("Not inside a Git repository. Run this command in a repository.")
        }
        root = URL(fileURLWithPath: result.output.trimmingCharacters(in: .newlines), isDirectory: true)
    }

    public func git(_ arguments: [String]) throws -> ProcessResult {
        try runner.run("/usr/bin/git", arguments, directory: root)
    }

    public func config(_ key: String, local: Bool = false) throws -> String? {
        let result = try git(["config"] + (local ? ["--local"] : []) + ["--get", key])
        guard result.status == 0 else { return nil }
        return result.output.trimmingCharacters(in: .newlines)
    }

    public func configWithOrigin(_ key: String) throws -> String {
        let result = try git(["config", "--show-origin", "--get", key])
        guard result.status == 0 else { return "(not set)" }
        // SSH commands may contain arbitrary shell text or secrets.
        if key == "core.sshCommand" {
            let origin = result.output.components(separatedBy: "\t").first ?? "unknown"
            return "\(origin): (configured; command hidden)"
        }
        return result.output.trimmingCharacters(in: .newlines).replacingOccurrences(of: "\t", with: ": ")
    }

    public func remotes() throws -> [(String, String, String)] {
        try rawRemotes().map { ($0.0, $0.1, redactRemote($0.2)) }
    }

    /// Raw URLs are for validation only and must never be printed or logged.
    public func rawRemotes() throws -> [(String, String, String)] {
        let result = try git(["remote"])
        guard result.status == 0 else { throw AccountError.message("Could not enumerate Git remotes.") }
        var rows: [(String, String, String)] = []
        for name in result.output.split(whereSeparator: \.isNewline).map(String.init) {
            for direction in ["fetch", "push"] {
                let arguments = direction == "push" ? ["remote", "get-url", "--push", "--all", name] : ["remote", "get-url", "--all", name]
                let urls = try git(arguments)
                guard urls.status == 0 else { throw AccountError.message("Could not inspect remote URLs.") }
                for url in urls.output.split(whereSeparator: \.isNewline) {
                    rows.append((name, direction, String(url)))
                }
            }
        }
        return rows
    }
}

/// Display only the scheme and host of a remote, never credentials, path, query, or fragment.
public func redactRemote(_ value: String) -> String {
    if let components = URLComponents(string: value), let scheme = components.scheme, value.contains("://") {
        return "\(scheme)://\(components.host ?? "(unknown)")/…"
    }
    if let colon = value.firstIndex(of: ":"), !value.hasPrefix("/") {
        let hostPart = value[..<colon].split(separator: "@").last.map(String.init) ?? "(unknown)"
        // Do not echo arbitrary remote text as a hostname.
        if hostPart.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil {
            return "\(hostPart):…"
        }
    }
    return "(local or unsupported remote)"
}
