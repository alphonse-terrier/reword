import Foundation

/// Strips common Markdown formatting from a model's reply, since replies get pasted into
/// arbitrary text fields (chat messages, forms, plain-text notes) that don't render Markdown —
/// leaving raw `**`/`#`/`[]()` in place would look broken rather than formatted.
enum MarkdownStripper {
    /// Pure and testable: no I/O, just string transforms.
    static func strip(_ input: String) -> String {
        var result = input

        // Fenced code blocks: drop the ``` markers (with an optional language tag), keep the code.
        result = replacing(result, pattern: "```[a-zA-Z0-9]*", with: "")

        // Images ![alt](url) -> alt, then links [text](url) -> text.
        result = replacing(result, pattern: "!\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1")
        result = replacing(result, pattern: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1")

        // Emphasis, longest markers first so "***bold italic***" doesn't leave stray asterisks.
        result = replacing(result, pattern: "(\\*\\*\\*|___)(.+?)\\1", with: "$2")
        result = replacing(result, pattern: "(\\*\\*|__)(.+?)\\1", with: "$2")
        result = replacing(result, pattern: "(?<!\\w)(\\*|_)(.+?)\\1(?!\\w)", with: "$2")

        // Strikethrough and inline code.
        result = replacing(result, pattern: "~~(.+?)~~", with: "$1")
        result = replacing(result, pattern: "`([^`]+)`", with: "$1")

        // Line-leading markers: headers, blockquotes, list bullets, numbered lists.
        result = replacing(result, pattern: "(?m)^#{1,6}[ \\t]+", with: "")
        result = replacing(result, pattern: "(?m)^>[ \\t]?", with: "")
        result = replacing(result, pattern: "(?m)^[ \\t]*[-*+][ \\t]+", with: "")
        result = replacing(result, pattern: "(?m)^[ \\t]*\\d+\\.[ \\t]+", with: "")

        // Horizontal rules: a line consisting solely of 3+ -, *, or _.
        result = replacing(result, pattern: "(?m)^(-{3,}|\\*{3,}|_{3,})[ \\t]*$", with: "")

        // Collapse blank lines left behind by removed headers/rules.
        result = replacing(result, pattern: "\\n{3,}", with: "\n\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacing(_ input: String, pattern: String, with template: String) -> String {
        input.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
}
