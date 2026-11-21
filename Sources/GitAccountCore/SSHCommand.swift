import Foundation

public enum SSHCommand {
    /// Git invokes core.sshCommand via a shell. Quote the key path as exactly
    /// one POSIX shell word; OpenSSH expands % and $ even within shell quotes.
    public static func make(keyPath: String) throws -> String {
        guard keyPath.hasPrefix("/"),
              !keyPath.contains("%"), !keyPath.contains("$"),
              keyPath.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw AccountError.message("SSH key path must be absolute and must not contain control or expansion characters.")
        }
        let quoted = "'" + keyPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "/usr/bin/ssh -i \(quoted) -o IdentitiesOnly=yes -S none -o PreferredAuthentications=publickey"
    }

    public static func validateKeyFile(_ path: String) throws {
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &directory), !directory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else {
            throw AccountError.message("SSH key file is missing or unreadable. Check the profile's key path.")
        }
    }
}
