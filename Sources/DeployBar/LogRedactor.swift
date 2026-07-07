import Foundation

enum LogRedactor {
    static func redact(_ text: String) -> String {
        var redacted = text
        let patterns: [(String, String)] = [
            (#"(?i)\b(password|passwd|pwd|token|secret|api[_-]?key|access[_-]?key)\s*=\s*("[^"]*"|'[^']*'|[^\s]+)"#, "$1=********"),
            (#"(?i)\b(sshPassword|ssh_password)\s*:\s*("[^"]*"|'[^']*'|[^\s]+)"#, "$1: ********"),
            (#"(?i)\b(SSHPASS=)("[^"]*"|'[^']*'|[^\s]+)"#, "$1'********'"),
            (#"(?i)(--password|-p)\s+("[^"]*"|'[^']*'|[^\s]+)"#, "$1 ********"),
            (#"(?i)(sshpass\s+-p\s+)("[^"]*"|'[^']*'|[^\s]+)"#, "$1'********'"),
            (#"(?i)(Authorization:\s*Bearer\s+)[^\s]+"#, "$1********")
        ]

        for (pattern, replacement) in patterns {
            redacted = replace(pattern: pattern, in: redacted, with: replacement)
        }
        return redacted
    }

    private static func replace(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
