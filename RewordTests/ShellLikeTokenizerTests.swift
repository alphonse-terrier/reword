import XCTest
@testable import Reword

final class ShellLikeTokenizerTests: XCTestCase {
    func testSimpleTokens() {
        XCTAssertEqual(ShellLikeTokenizer.tokenize("-p --model gpt-4"), ["-p", "--model", "gpt-4"])
    }

    func testDoubleQuotedTokenWithSpaces() {
        XCTAssertEqual(ShellLikeTokenizer.tokenize("--flag \"hello world\""), ["--flag", "hello world"])
    }

    func testSingleQuotedToken() {
        XCTAssertEqual(ShellLikeTokenizer.tokenize("run 'hello world' now"), ["run", "hello world", "now"])
    }

    func testPlaceholderTokenSurvivesQuoting() {
        XCTAssertEqual(
            ShellLikeTokenizer.tokenize("--system-prompt \"{system}\" --model {model}"),
            ["--system-prompt", "{system}", "--model", "{model}"]
        )
    }

    func testEmptyInput() {
        XCTAssertEqual(ShellLikeTokenizer.tokenize(""), [])
    }

    func testExtraWhitespaceCollapsed() {
        XCTAssertEqual(ShellLikeTokenizer.tokenize("  -p    --model  "), ["-p", "--model"])
    }
}
