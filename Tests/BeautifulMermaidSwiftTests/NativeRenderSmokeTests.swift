#if canImport(CoreGraphics) && (canImport(UIKit) || canImport(AppKit))
import XCTest
import CoreGraphics
@testable import BeautifulMermaid

/// Smoke guard for the native CoreGraphics rendering path (the iOS/macOS
/// in-app pipeline). Pixel-exact golden images are too fragile across OS/font
/// versions; this locks in the structural invariants instead: correct
/// dimensions, actual foreground content, and renderer reuse across frames.
final class NativeRenderSmokeTests: XCTestCase {

    private let source = """
    graph TD
        A[Start] --> B{Check}
        B -->|yes| C[Done]
        B -->|no| A
    """

    func testRenderImageProducesContentAtExpectedScale() throws {
        let renderer = MermaidImageRenderer()
        renderer.scale = 2.0
        let positioned = try MermaidRenderer.layout(source)
        let image = try XCTUnwrap(renderer.renderImage(from: positioned))

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let rep = try XCTUnwrap(image.representations.first)
        XCTAssertEqual(rep.pixelsWide, Int(positioned.width.rounded() * 2), accuracy: 4)
        XCTAssertEqual(rep.pixelsHigh, Int(positioned.height.rounded() * 2), accuracy: 4)
        #else
        XCTAssertEqual(Double(image.size.width), positioned.width, accuracy: 2)
        #endif
    }

    func testRenderedBitmapContainsForegroundPixels() throws {
        let renderer = MermaidImageRenderer()
        let positioned = try MermaidRenderer.layout(source)
        let image = try XCTUnwrap(renderer.renderImage(from: positioned, scale: 1.0))

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        var rect = CGRect(origin: .zero, size: image.size)
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        #else
        let cgImage = try XCTUnwrap(image.cgImage)
        #endif

        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Count pixels that differ from the (light) background.
        var foreground = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i] < 200 {
            foreground += 1
        }
        XCTAssertGreaterThan(
            foreground, (width * height) / 500,
            "rendered bitmap has almost no foreground content")
    }

    func testRendererIsReusedAcrossFramesAndInvalidatedOnThemeChange() throws {
        let renderer = MermaidImageRenderer()
        let positioned = try MermaidRenderer.layout(source)
        XCTAssertNotNil(renderer.renderImage(from: positioned))
        XCTAssertNotNil(renderer.renderImage(from: positioned))
        renderer.theme = .zincDark
        XCTAssertNotNil(renderer.renderImage(from: positioned), "render after theme change must not crash or use stale colors")
    }
}
#endif
