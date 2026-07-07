import Foundation

enum ShellEnvironment {
    static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = [
            "\(home)/Library/pnpm",
            "\(home)/.local/share/pnpm",
            "\(home)/.npm-global/bin",
            "\(home)/.nvm/current/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let currentPath = environment["PATH"] ?? ""
        let mergedPath = (extraPaths + currentPath.split(separator: ":").map(String.init))
            .reduce(into: [String]()) { result, path in
                if !result.contains(path) {
                    result.append(path)
                }
            }
            .joined(separator: ":")

        environment["HOME"] = home
        environment["SHELL"] = "/bin/zsh"
        environment["PATH"] = mergedPath
        environment["PNPM_HOME"] = environment["PNPM_HOME"] ?? "\(home)/Library/pnpm"
        return environment
    }

    static func wrappedCommand(_ command: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return """
        export HOME='\(escapeSingleQuotes(home))'
        export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
        export PATH="$PNPM_HOME:$HOME/.local/share/pnpm:$HOME/.npm-global/bin:$HOME/.nvm/current/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
        [ -f /etc/zprofile ] && source /etc/zprofile
        [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"
        [ -f "$HOME/.zshenv" ] && source "$HOME/.zshenv"
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"
        \(command)
        """
    }

    private static func escapeSingleQuotes(_ text: String) -> String {
        text.replacingOccurrences(of: "'", with: "'\\''")
    }
}

