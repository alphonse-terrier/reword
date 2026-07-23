import Foundation

enum ShellLikeTokenizer {
    /// Splits a shell-like argument string into tokens, honoring single/double quotes so a
    /// quoted placeholder like `"{system}"` stays one token — this matters because after
    /// substitution that token can contain spaces or newlines (a whole system prompt), which
    /// must be passed to `Process` as a single argument, not word-split.
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var hasCurrent = false

        for char in input {
            switch char {
            case "'" where !inDoubleQuotes:
                inSingleQuotes.toggle()
                hasCurrent = true
            case "\"" where !inSingleQuotes:
                inDoubleQuotes.toggle()
                hasCurrent = true
            case let c where c.isWhitespace && !inSingleQuotes && !inDoubleQuotes:
                if hasCurrent {
                    tokens.append(current)
                    current = ""
                    hasCurrent = false
                }
            default:
                current.append(char)
                hasCurrent = true
            }
        }
        if hasCurrent { tokens.append(current) }
        return tokens
    }
}
