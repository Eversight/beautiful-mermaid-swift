#if canImport(UIKit) || canImport(AppKit)
import XCTest
import CoreGraphics
@testable import BeautifulMermaid

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Regression tests for the three view-pipeline bugs the async raster
/// rewrite introduced (found by Phrase's editor cells):
///
/// 1. **Missing labels (UIKit).** `NSAttributedString.draw(in:)` renders into
///    UIKit's *current* graphics context; the background raster queue draws
///    into a bare `CGContext` where none is current, so every label was a
///    silent no-op. Fixed by `UIGraphicsPushContext` in `LabelRenderer`.
/// 2. **Blank recycled cells.** `MermaidView` wired its contents pipeline
///    through the public `onPrepareComplete`, so a consumer replacing that
///    hook (a documented extension point) disconnected the view from its own
///    layer: a cell that cleared `source` on reuse and re-set it on return
///    never repopulated `layer.contents`. Fixed by the internal
///    `onPrepareCompleteForView` hook.
/// 3. **Sometimes-blurry contents.** The raster queue is concurrent, and
///    deliveries only checked `contentGeneration` — an older smaller-size
///    raster finishing late overwrote a newer crisp one, and `.resizeAspect`
///    GPU-stretched the low-res image. Fixed by last-request-wins sequencing.
final class ViewContentsRegressionTests: XCTestCase {

    /// Label-heavy on purpose: text must dominate the ink so a text-less
    /// render is unmistakably below the ink-ratio floor in the raster test.
    private let source = """
    graph TD
        A[Wide Label With Many Words] --> B{Branching Check Node Label}
        B -->|yes indeed| C[Another Long Label Here]
        B -->|not at all| D[Final Wordy Terminal Label]
    """

    private func pump(until condition: @escaping () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func preparedLayer(_ source: String) -> MermaidLayer {
        let layer = MermaidLayer()
        let prepared = expectation(description: "prepared")
        layer.onPrepareComplete = { prepared.fulfill() }
        layer.source = source
        wait(for: [prepared], timeout: 5)
        // Detach: later source changes in the test publish again, and a stale
        // hook would double-fulfill the expectation (an XCTest API violation).
        layer.onPrepareComplete = nil
        return layer
    }

    // MARK: - 1. Text must survive the background raster path

    func testBackgroundRasterRendersText() throws {
        let layer = preparedLayer(source)
        XCTAssertNil(layer.parseError)
        XCTAssertGreaterThan(layer.diagramBounds.width, 0)

        // Reference: `renderImage` draws inside UIGraphicsImageRenderer /
        // NSImage lockFocus, where a current context always exists and text
        // has always rendered. The background raster must contain (nearly)
        // the same ink; missing labels cut it far below the floor.
        //
        // Request the raster at the reference's *actual pixel* dimensions:
        // on macOS, `lockFocus` allocates the backing store at the screen's
        // scale factor, so the reference CGImage is device-scale × the
        // requested scale — comparing ink counts is only meaningful when
        // both images share pixel dimensions.
        let reference = try XCTUnwrap(layer.renderImage(scale: 2)?.bm_testCGImage)

        var raster: CGImage?
        layer.requestRaster(pixelSize: CGSize(width: reference.width, height: reference.height)) {
            raster = $0
        }
        pump(until: { raster != nil })
        let rasterImage = try XCTUnwrap(raster, "background raster must deliver")

        let rasterInk = Self.inkPixelCount(rasterImage)
        let referenceInk = Self.inkPixelCount(reference)

        XCTAssertGreaterThan(referenceInk, 500, "reference render should contain meaningful ink")
        XCTAssertGreaterThanOrEqual(
            Double(rasterInk), Double(referenceInk) * 0.85,
            "background raster ink (\(rasterInk)) far below reference (\(referenceInk)) — labels missing?"
        )
    }

    // MARK: - 2. Consumer-replaced hook must not blank the view

    func testViewSurvivesConsumerReplacingPrepareHookAcrossReuseCycle() {
        let view = MermaidView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        // What Phrase's block cell does: claim the public hook for its own
        // geometry bookkeeping. This must not disconnect the view's pipeline.
        var consumerPrepares = 0
        view.mermaidLayer.onPrepareComplete = { consumerPrepares += 1 }

        // No manual layout passes anywhere in this test: the view must reach
        // contents purely via its internal prepare hook, because a recycled
        // cell whose frame didn't change gets no layout pass either.
        view.source = source
        pump(until: { self.contents(of: view) != nil })
        XCTAssertNotNil(contents(of: view),
            "view must populate layer.contents even when onPrepareComplete is replaced by a consumer")
        XCTAssertGreaterThan(consumerPrepares, 0, "consumer's hook must keep firing")

        // Cell recycle: clear (publishes synchronously for empty source)…
        view.source = ""
        XCTAssertNil(view.mermaidLayer.preparedDiagram)
        XCTAssertNil(contents(of: view), "cleared source must clear stale contents")

        // …then scroll back: same source re-bound. This exact sequence used
        // to leave the cell blank forever.
        view.source = source
        pump(until: { self.contents(of: view) != nil })
        XCTAssertNotNil(contents(of: view), "re-bound source must repopulate contents (blank-cell regression)")
        XCTAssertGreaterThanOrEqual(consumerPrepares, 3, "one prepare per source change")
    }

    // MARK: - 2b. Clearing/failing content must invalidate in-flight rasters

    func testClearingSourceBumpsContentGeneration() {
        let layer = preparedLayer(source)
        let before = layer.contentGeneration

        layer.source = ""
        XCTAssertNil(layer.preparedDiagram)
        XCTAssertNotEqual(layer.contentGeneration, before,
            "clearing must bump the content generation so stale raster deliveries are dropped")
    }

    func testParseFailureBumpsContentGeneration() {
        let layer = preparedLayer(source)
        let before = layer.contentGeneration

        let failed = expectation(description: "failure published")
        layer.onPrepareComplete = { failed.fulfill() }
        layer.source = "notadiagram\nA --> B"
        wait(for: [failed], timeout: 5)

        XCTAssertNotNil(layer.parseError)
        XCTAssertNil(layer.preparedDiagram)
        XCTAssertNotEqual(layer.contentGeneration, before,
            "a failed parse must bump the content generation so stale raster deliveries are dropped")
    }

    // MARK: - 3. Last-requested raster size must win

    func testNewestRequestedRasterSizeAlwaysWins() {
        let layer = preparedLayer(source)

        let small = CGSize(width: 80, height: 60)
        let big = CGSize(width: 800, height: 600)
        var lastDeliveredWidth: Int?

        // Hammer alternating sizes, ending on `big`, with interleaved pumping
        // so deliveries race the requests the way live layout passes do. On a
        // concurrent queue the small raster regularly completes after the big
        // one; whatever the completion order, the final delivery must match
        // the final request.
        for i in 0..<25 {
            layer.requestRaster(pixelSize: small) { lastDeliveredWidth = $0.width }
            layer.requestRaster(pixelSize: big) { lastDeliveredWidth = $0.width }
            if i % 5 == 0 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
        }

        // The newest request always delivers exactly once (all 49 stale ones
        // are dropped); wait for it, then settle until deliveries stop, so a
        // loaded machine can't exit before the surviving delivery lands.
        pump(until: { layer.rasterRenderCount > 0 })
        var stableCount = -1
        while stableCount != layer.rasterRenderCount {
            stableCount = layer.rasterRenderCount
            pump(until: { false }, timeout: 0.25)
        }

        XCTAssertEqual(lastDeliveredWidth, Int(big.width),
            "an older small raster finishing late must never overwrite the newest requested size (blur regression)")
    }

    // MARK: - 3b. Returning to a previously delivered size must re-render

    func testReRequestingAPreviouslyDeliveredSizeReRenders() {
        let layer = preparedLayer(source)
        let a = CGSize(width: 300, height: 200), b = CGSize(width: 600, height: 400)
        var widths: [Int] = []

        layer.requestRaster(pixelSize: a) { widths.append($0.width) }
        pump(until: { widths.count == 1 })
        layer.requestRaster(pixelSize: b) { widths.append($0.width) }
        pump(until: { widths.count == 2 })
        // Back to A. The dedup latch must key on the newest *requested*
        // state, not on delivery history — a delivered-keys latch (the old
        // scheme's shape) would swallow this request and a view resized back
        // to a previous size would keep GPU-stretching the B-sized image.
        layer.requestRaster(pixelSize: a) { widths.append($0.width) }
        pump(until: { widths.count == 3 })

        XCTAssertEqual(widths, [300, 600, 300],
            "returning to a previously delivered size must deliver a fresh raster")
    }

    // MARK: - 4. Theme change must refresh composited view contents

    func testThemeChangeRefreshesViewContents() {
        let view = MermaidView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.source = source
        pump(until: { self.contents(of: view) != nil })
        let before = contents(of: view) as AnyObject?
        let deliveredBefore = view.mermaidLayer.rasterRenderCount

        // Theme is the cheapest invalidation: it only rebuilds the render
        // closure and fires no prepare hooks, so the view's theme setter must
        // re-request the raster itself. If that link breaks, the diagram
        // keeps its old colors forever.
        view.theme = DiagramTheme(background: .black, foreground: .white)
        pump(until: { view.mermaidLayer.rasterRenderCount > deliveredBefore })

        XCTAssertGreaterThan(view.mermaidLayer.rasterRenderCount, deliveredBefore,
            "theme change must trigger a re-raster")
        XCTAssertFalse(contents(of: view) as AnyObject === before,
            "theme change must swap the composited image")
    }

    // MARK: - Helpers

    private func contents(of view: MermaidView) -> Any? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return view.layer?.contents
        #else
        return view.layer.contents
        #endif
    }

    /// Counts "ink" pixels: opaque and dark, i.e. strokes and label glyphs in
    /// the zinc-light theme (foreground #27272A). White/transparent background
    /// contributes nothing, so the count tracks drawn geometry + text.
    private static func inkPixelCount(_ image: CGImage) -> Int {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var count = 0
        var i = 0
        while i < pixels.count {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
            if a > 127 && r < 120 && g < 120 && b < 120 {
                count += 1
            }
            i += 4
        }
        return count
    }
}

private extension BMImage {
    var bm_testCGImage: CGImage? {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return cgImage
        #elseif canImport(AppKit)
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}
#endif
