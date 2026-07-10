import XCTest
@testable import BeautifulMermaid

/// Locks character-width behavior. The ASCII fast path in `getCharWidth` must not
/// change any width: ASCII stays at its classified width, and non-ASCII fullwidth
/// / emoji characters must still resolve to 2.0 (they take `code >= 0x80` branch).
final class TextMetricsTests: XCTestCase {

    private func width(_ s: String) -> Double {
        TextMetrics.getCharWidth(Character(s))
    }

    func test_asciiWidths() {
        XCTAssertEqual(width("W"), 1.5, accuracy: 1e-9)   // very wide
        XCTAssertEqual(width("M"), 1.5, accuracy: 1e-9)
        XCTAssertEqual(width("w"), 1.2, accuracy: 1e-9)   // wide
        XCTAssertEqual(width("i"), 0.4, accuracy: 1e-9)   // narrow
        XCTAssertEqual(width("l"), 0.4, accuracy: 1e-9)
        XCTAssertEqual(width("("), 0.5, accuracy: 1e-9)   // semi-narrow punct
        XCTAssertEqual(width("r"), 0.8, accuracy: 1e-9)
        XCTAssertEqual(width("A"), 1.2, accuracy: 1e-9)   // uppercase
        XCTAssertEqual(width("1"), 0.4, accuracy: 1e-9)   // '1' is in NARROW_CHARS (checked before the digit range)
        XCTAssertEqual(width("2"), 1.0, accuracy: 1e-9)   // other digits hit the 48...57 range
        XCTAssertEqual(width("x"), 1.0, accuracy: 1e-9)   // default
        XCTAssertEqual(width(" "), 0.3, accuracy: 1e-9)   // space
    }

    func test_fullwidthAndEmojiStillTwo() {
        // Non-ASCII fullwidth (CJK, Hiragana, Hangul) must still be 2.0.
        XCTAssertEqual(width("中"), 2.0, accuracy: 1e-9)
        XCTAssertEqual(width("あ"), 2.0, accuracy: 1e-9)
        XCTAssertEqual(width("한"), 2.0, accuracy: 1e-9)
        // Emoji must still be 2.0.
        XCTAssertEqual(width("😀"), 2.0, accuracy: 1e-9)
        XCTAssertEqual(width("🎉"), 2.0, accuracy: 1e-9)
    }

    func test_combiningMarkIsZero() {
        let combining = Character(Unicode.Scalar(0x0301)!) // combining acute accent
        XCTAssertEqual(TextMetrics.getCharWidth(combining), 0.0, accuracy: 1e-9)
    }

    func test_measureMultilineText_stripsTagsAndMeasuresWidest() {
        // Tagged and untagged content of the same visible text measure identically.
        let tagged = TextMetrics.measureMultilineText("<b>Hello</b>", fontSize: 14, fontWeight: 400)
        let plain = TextMetrics.measureMultilineText("Hello", fontSize: 14, fontWeight: 400)
        XCTAssertEqual(tagged.width, plain.width, accuracy: 1e-9)
        XCTAssertEqual(tagged.height, plain.height, accuracy: 1e-9)
    }
}
