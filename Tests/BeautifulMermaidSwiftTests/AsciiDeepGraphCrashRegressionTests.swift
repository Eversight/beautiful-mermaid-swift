import XCTest
@testable import BeautifulMermaid

/// Regression tests for the ASCII grid mapping crash on deep graphs.
///
/// `createMapping` used a fixed-size `highestPositionPerLevel` table of 100
/// entries, indexed by `childLevel` which grows by 4 per graph-depth level.
/// Any flowchart deeper than ~25 levels indexed out of range and trapped with
/// "Index out of range". The table now grows on demand.
final class AsciiDeepGraphCrashRegressionTests: XCTestCase {

    /// A linear chain deeper than the old 100/4 = 25-level limit must render.
    func test_deepLinearChain_asciiDoesNotCrash() throws {
        var source = "graph TD\n"
        let depth = 40 // childLevel reaches 4*40 = 160, well past the old cap of 100
        for i in 0..<depth {
            source += "    N\(i)[Node \(i)]\n"
        }
        for i in 0..<(depth - 1) {
            source += "    N\(i) --> N\(i + 1)\n"
        }

        let ascii = try MermaidRenderer.renderASCII(source: source)
        XCTAssertFalse(ascii.isEmpty, "Expected non-empty ASCII for a deep chain")
    }

    /// Left-to-right direction indexes the level table by x; verify it too.
    func test_deepLinearChain_LR_asciiDoesNotCrash() throws {
        var source = "graph LR\n"
        let depth = 40
        for i in 0..<depth {
            source += "    N\(i)[Node \(i)]\n"
        }
        for i in 0..<(depth - 1) {
            source += "    N\(i) --> N\(i + 1)\n"
        }

        let ascii = try MermaidRenderer.renderASCII(source: source)
        XCTAssertFalse(ascii.isEmpty, "Expected non-empty ASCII for a deep LR chain")
    }
}
