import Foundation

public struct SSHConfigInspector {
    public init() {}

    /// Fail closed when OpenSSH reports an additional identity or certificate.
    /// This is a local configuration check, not a server authentication test.
    public func validate(destination: SSHRemote, keyPath: String) throws {
        try SSHCommand.validateKeyFile(keyPath)
        var arguments = ["-G", "-i", keyPath, "-o", "IdentitiesOnly=yes", "-S", "none",
                         "-o", "PreferredAuthentications=publickey"]
        if let port = destination.port { arguments += ["-p", String(port)] }
        if let user = destination.user { arguments += ["-l", user] }
        arguments.append(destination.host)
        let result = try ProcessRunner().run("/usr/bin/ssh", arguments)
        guard result.status == 0 else {
            throw AccountError.message("Could not inspect effective SSH configuration for a remote.")
        }
        try Self.validateEffectiveConfig(result.output, keyPath: keyPath)
    }

    public static func validateEffectiveConfig(_ output: String, keyPath: String) throws {
        var foundKey = false
        var identitiesOnly = false
        var disabledMultiplexing = false
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch parts[0].lowercased() {
            case "identityfile":
                let expanded = (value as NSString).expandingTildeInPath
                guard !expanded.contains("%"), !expanded.contains("$"),
                      URL(fileURLWithPath: expanded).standardizedFileURL.path == keyPath else {
                    throw AccountError.message("SSH configuration contains another IdentityFile; remove the conflict before switching.")
                }
                foundKey = true
            case "certificatefile":
                guard value.lowercased() == "none" else {
                    throw AccountError.message("SSH configuration contains a CertificateFile; remove the conflict before switching.")
                }
            case "identitiesonly":
                identitiesOnly = value.lowercased() == "yes"
            case "controlpath":
                disabledMultiplexing = value.lowercased() == "none"
            default: break
            }
        }
        guard foundKey, identitiesOnly, disabledMultiplexing else {
            throw AccountError.message("SSH configuration could not be verified safely; no changes were made.")
        }
    }
}
