import XCTest
@testable import Reword

final class MarkdownStripperTests: XCTestCase {
    func testBold() {
        XCTAssertEqual(MarkdownStripper.strip("This is **bold** text."), "This is bold text.")
        XCTAssertEqual(MarkdownStripper.strip("This is __bold__ text."), "This is bold text.")
    }

    func testItalic() {
        XCTAssertEqual(MarkdownStripper.strip("This is *italic* text."), "This is italic text.")
        XCTAssertEqual(MarkdownStripper.strip("This is _italic_ text."), "This is italic text.")
    }

    func testBoldItalic() {
        XCTAssertEqual(MarkdownStripper.strip("This is ***important***."), "This is important.")
    }

    func testDoesNotMangleSnakeCaseIdentifiers() {
        XCTAssertEqual(MarkdownStripper.strip("Use my_variable_name here."), "Use my_variable_name here.")
    }

    func testStrikethrough() {
        XCTAssertEqual(MarkdownStripper.strip("This is ~~wrong~~ right."), "This is wrong right.")
    }

    func testInlineCode() {
        XCTAssertEqual(MarkdownStripper.strip("Run `swift build` now."), "Run swift build now.")
    }

    func testFencedCodeBlock() {
        XCTAssertEqual(MarkdownStripper.strip("```swift\nlet x = 1\n```"), "let x = 1")
    }

    func testHeaders() {
        XCTAssertEqual(MarkdownStripper.strip("# Title\nBody text"), "Title\nBody text")
        XCTAssertEqual(MarkdownStripper.strip("### Subheading"), "Subheading")
    }

    func testLinks() {
        XCTAssertEqual(MarkdownStripper.strip("See [the docs](https://example.com) for more."), "See the docs for more.")
    }

    func testImages() {
        XCTAssertEqual(MarkdownStripper.strip("![a cat](https://example.com/cat.png)"), "a cat")
    }

    func testBulletList() {
        XCTAssertEqual(MarkdownStripper.strip("- one\n- two\n- three"), "one\ntwo\nthree")
        XCTAssertEqual(MarkdownStripper.strip("* one\n* two"), "one\ntwo")
    }

    func testNumberedList() {
        XCTAssertEqual(MarkdownStripper.strip("1. one\n2. two"), "one\ntwo")
    }

    func testBlockquote() {
        XCTAssertEqual(MarkdownStripper.strip("> quoted line"), "quoted line")
    }

    func testHorizontalRule() {
        XCTAssertEqual(MarkdownStripper.strip("above\n---\nbelow"), "above\n\nbelow")
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual(MarkdownStripper.strip("Just a normal sentence."), "Just a normal sentence.")
    }

    func testCombined() {
        let input = "# Summary\n\nHere's the **key point**: use `foo()` instead of *bar()*.\n\n- fast\n- simple"
        let expected = "Summary\n\nHere's the key point: use foo() instead of bar().\n\nfast\nsimple"
        XCTAssertEqual(MarkdownStripper.strip(input), expected)
    }
}
