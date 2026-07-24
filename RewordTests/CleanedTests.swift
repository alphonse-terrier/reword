import XCTest
@testable import Reword

final class CleanedTests: XCTestCase {
    private struct DummyProvider: LLMProvider {
        func reformulate(text: String, systemPrompt: String) async throws -> String { text }
    }

    private let provider = DummyProvider()

    func testStripsCodeFences() {
        XCTAssertEqual(provider.cleaned("```\nhello\n```"), "hello")
    }

    func testStripsSurroundingQuotes() {
        XCTAssertEqual(provider.cleaned("\"hello world\""), "hello world")
    }

    func testStripsThinkBlock() {
        let raw = "<think>reasoning about stuff\nmore reasoning</think>final answer"
        XCTAssertEqual(provider.cleaned(raw), "final answer")
    }

    func testStripsThinkBlockCaseInsensitive() {
        let raw = "<THINK>nope</THINK>answer"
        XCTAssertEqual(provider.cleaned(raw), "answer")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(provider.cleaned("  hello  \n"), "hello")
    }

    func testLeavesPlainTextUnchanged() {
        XCTAssertEqual(provider.cleaned("just a normal reply"), "just a normal reply")
    }

    func testStripsMarkdownFormatting() {
        XCTAssertEqual(provider.cleaned("This is **bold** and *italic*."), "This is bold and italic.")
    }

    func testStripsBoldWrappedQuotes() {
        // Markdown stripping must run before the surrounding-quote check, or the quotes stay
        // hidden behind the bold markers and never get stripped.
        XCTAssertEqual(provider.cleaned("**\"Hello\"**"), "Hello")
    }
}
