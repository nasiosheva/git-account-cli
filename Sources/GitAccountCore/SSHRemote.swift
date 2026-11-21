import Foundation

/// A Git SSH destination. Keep the original host alias for ssh_config matching.
public struct SSHRemote: Equatable {
    public let host: String
    public let user: String?
    public let port: Int?

    public static func parse(_ value: String) -> SSHRemote? {
        guard !value.isEmpty,
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        if value.contains("://") {
            guard let url = URLComponents(string: value),
                  url.scheme?.lowercased() == "ssh",
                  let host = url.host, validHost(host),
                  url.password == nil, url.query == nil, url.fragment == nil,
                  !url.path.isEmpty,
                  url.user.map(validUser) ?? true,
                  url.port.map({ (1...65535).contains($0) }) ?? true else { return nil }
            return SSHRemote(host: host, user: url.user, port: url.port)
        }
        guard !value.hasPrefix("/"), !value.hasPrefix("./"), !value.hasPrefix("../"),
              let colon = value.firstIndex(of: ":"),
              !value[value.index(after: colon)...].isEmpty else { return nil }
        let destination = String(value[..<colon])
        let pieces = destination.split(separator: "@", omittingEmptySubsequences: false)
        guard pieces.count == 1 || pieces.count == 2 else { return nil }
        let host = String(pieces.last!)
        let user = pieces.count == 2 ? String(pieces[0]) : nil
        guard validHost(host), user.map(validUser) ?? true else { return nil }
        return SSHRemote(host: host, user: user, port: nil)
    }

    private static func validHost(_ host: String) -> Bool {
        !host.hasPrefix("-") && host.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
    }

    private static func validUser(_ user: String) -> Bool {
        !user.hasPrefix("-") && user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
    }
}
