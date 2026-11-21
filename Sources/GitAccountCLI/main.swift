import Foundation
import GitAccountCore
import Darwin

let mainHelp = """
OVERVIEW: Manage Git commit identity and SSH keys per repository.

USAGE: git-account <subcommand>

OPTIONS:
  -h, --help              Show help.
  --version               Show the application version.

SUBCOMMANDS:
  profile                 Create, view, and remove saved profiles.
  use                     Apply a profile to the current repository.
  status                  Show the current repository's Git and SSH settings.
  doctor                  Diagnose local Git and SSH settings.
  unbind                  Remove the profile binding from the current repository.

Run 'git-account <subcommand> --help' for details and examples.
"""
let helps: [String: String] = [
    "profile": """
    OVERVIEW: Create, view, and remove saved profiles.
    USAGE: git-account profile <subcommand>
    OPTIONS: -h, --help  Show help.
    SUBCOMMANDS: add, list, show, remove
    EXAMPLE: git-account profile list
    """,
    "profile add": """
    OVERVIEW: Save a profile. Run use again in each repository after updating it.
    USAGE: git-account profile add <id> --name <name> --email <email> --ssh-key <path> [--replace]
    ARGUMENTS: <id> Profile ID.
    OPTIONS: --name <name>  --email <email>  --ssh-key <path>  --replace  -h, --help
    EXAMPLE: git-account profile add kantor --name "Nama Kerja" --email saya@kantor.example --ssh-key ~/.ssh/id_ed25519_kantor
    """,
    "profile list": "OVERVIEW: List saved profiles.\\nUSAGE: git-account profile list\\nOPTIONS: -h, --help\\nEXAMPLE: git-account profile list",
    "profile show": "OVERVIEW: Show a profile.\\nUSAGE: git-account profile show <id>\\nARGUMENTS: <id> Profile ID.\\nOPTIONS: -h, --help\\nEXAMPLE: git-account profile show kantor",
    "profile remove": "OVERVIEW: Remove a profile. Run unbind in repositories to remove bindings.\\nUSAGE: git-account profile remove <id>\\nARGUMENTS: <id> Profile ID.\\nOPTIONS: -h, --help\\nEXAMPLE: git-account profile remove kantor",
    "use": """
    OVERVIEW: Apply a saved profile to the current repository.

    USAGE: git-account use <id> [--yes]

    ARGUMENTS:
      <id>                    Saved profile ID. Run 'git-account profile list' to see IDs.

    OPTIONS:
      --yes                   Apply without an interactive prompt.
      -h, --help              Show help.

    EXAMPLE:
      git-account use kantor
    """,
    "status": "OVERVIEW: Show repository Git and SSH settings.\\nUSAGE: git-account status\\nOPTIONS: -h, --help\\nEXAMPLE: git-account status",
    "doctor": "OVERVIEW: Diagnose local Git and SSH settings; server access is not checked.\\nUSAGE: git-account doctor\\nOPTIONS: -h, --help\\nEXAMPLE: git-account doctor",
    "unbind": "OVERVIEW: Remove the profile binding and restore managed settings.\\nUSAGE: git-account unbind\\nOPTIONS: -h, --help\\nEXAMPLE: git-account unbind"
]

func stderr(_ message: String) { FileHandle.standardError.write(Data((message + "\n").utf8)) }
func syntax(_ help: String) -> Never {
    stderr("Invalid arguments. Run 'git-account \(help)--help' for usage.")
    exit(2)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args == ["--help"] || args == ["-h"] { print(mainHelp); exit(0) }
if args == ["--version"] { print("0.1.0"); exit(0) }
let command = args[0]
guard ["profile", "use", "status", "doctor", "unbind"].contains(command) else { syntax("") }
let key = command == "profile" && args.count > 1 && !args[1].hasPrefix("-") ? "profile " + args[1] : command
guard helps[key] != nil else { syntax("profile ") }
if args.last == "--help" || args.last == "-h" {
    let expectedCount = key.hasPrefix("profile ") ? 3 : 2
    guard args.count == expectedCount else { syntax(key + " ") }
    print(helps[key]!.replacingOccurrences(of: "\\n", with: "\n"))
    exit(0)
}
if args == ["profile"] { print(helps["profile"]!); exit(0) }

do {
    let store = ProfileStore()
    switch key {
    case "profile list":
        guard args.count == 2 else { syntax("profile list ") }
        let profiles = try store.profiles()
        if profiles.isEmpty { print("No profiles. Create one with 'git-account profile add --help'.") }
        for id in profiles.keys.sorted() {
            let p = profiles[id]!
            print("\(id)\t\(p.name)\t\(p.email)")
        }
    case "profile show", "profile remove":
        guard args.count == 3, !args[2].hasPrefix("-") else { syntax(key + " ") }
        let id = args[2]
        if key == "profile remove" {
            try store.remove(id: id)
            print("Removed profile \(id). Run unbind in a repository to remove its binding.")
        } else {
            guard let p = try store.profiles()[id] else { throw AccountError.message("Profile not found: \(id)") }
            print("ID: \(id)\nName: \(p.name)\nEmail: \(p.email)\nSSH key: \(p.sshKeyPath)\nKey exists: \(FileManager.default.fileExists(atPath: p.sshKeyPath) ? "yes" : "no")")
        }
    case "profile add":
        guard args.count >= 3, !args[2].hasPrefix("-") else { syntax("profile add ") }
        var values: [String: String] = [:]
        var replace = false
        var i = 3
        while i < args.count {
            let flag = args[i]
            if flag == "--replace" {
                guard !replace else { syntax("profile add ") }
                replace = true; i += 1; continue
            }
            guard ["--name", "--email", "--ssh-key"].contains(flag), values[flag] == nil,
                  i + 1 < args.count, !args[i + 1].hasPrefix("--") else { syntax("profile add ") }
            values[flag] = args[i + 1]; i += 2
        }
        guard let name = values["--name"], let email = values["--email"], let path = values["--ssh-key"] else { syntax("profile add ") }
        let profile = Profile(name: name, email: email, sshKeyPath: try normalizedKeyPath(path))
        try store.add(id: args[2], profile: profile, replace: replace)
        print("Saved profile \(args[2]). Run use again in affected repositories to apply changes.")
    case "use":
        guard (args.count == 2 || (args.count == 3 && args[2] == "--yes")), !args[1].hasPrefix("-") else { syntax("use ") }
        guard try store.profiles()[args[1]] != nil else { throw AccountError.message("Profile not found: \(args[1])") }
        throw AccountError.message("Applying profiles is not implemented yet; no Git configuration was changed.")
    case "status", "doctor", "unbind":
        guard args.count == 1 else { syntax(key + " ") }
        let repo = try RepositoryInspector()
        if key == "unbind" {
            guard try repo.config("git-account.profile", local: true) == nil else {
                throw AccountError.message("Unbinding an existing profile is not implemented yet; no Git configuration was changed.")
            }
            print("No profile binding to remove.")
        } else if key == "status" {
            print("Repository: \(repo.root.path)")
            let remotes = try repo.remotes()
            if remotes.isEmpty { print("Remotes: (none)") }
            for (name, direction, url) in remotes { print("Remote \(name) (\(direction)): \(url)") }
            print("Commit identity:")
            print("  Name: \(try repo.configWithOrigin("user.name"))")
            print("  Email: \(try repo.configWithOrigin("user.email"))")
            print("SSH: \(try repo.configWithOrigin("core.sshCommand"))")
            if let marker = try repo.config("git-account.profile", local: true) {
                // A marker alone is not evidence that the installed configuration still matches.
                print("Profile marker: \(marker) (binding not verified; manual/different)")
            } else {
                print("Profile: manual/unbound")
            }
            for variable in ["GIT_SSH_COMMAND", "GIT_SSH", "GIT_SSH_VARIANT", "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"] {
                if ProcessInfo.processInfo.environment[variable] != nil { print("Override present: \(variable) (value hidden)") }
            }
        } else {
            print("Repository: \(repo.root.path)")
            let remotes = try repo.remotes()
            let origin = remotes.filter { $0.0 == "origin" }
            var problems = false
            if origin.isEmpty {
                print("Problem: origin is missing. Add an SSH origin remote.")
                problems = true
            } else {
                // Redacted form retains only a scheme/host, avoiding accidental disclosure.
                for (_, direction, url) in origin {
                    if !(url.hasPrefix("ssh://") || (!url.contains("://") && url.hasSuffix(":…") && !url.hasPrefix("(local"))) {
                        print("Problem: origin \(direction) is not SSH. Configure an SSH remote.")
                        problems = true
                    }
                }
            }
            if ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] == nil {
                print("Warning: SSH agent is not available; a passphrase prompt or Keychain may be required.")
            }
            print("Server access and push permission were not checked.")
            if problems { exit(1) }
        }
    default: syntax("profile ")
    }
} catch {
    stderr("Error: \(error.localizedDescription)")
    exit(1)
}
