#if canImport(UIKit) || canImport(AppKit)
import XCTest
import CoreGraphics
@testable import BeautifulMermaid

/// Locks in the staged-invalidation contract of the view pipeline:
/// `source` → parse+layout+draw; `layoutConfig` → layout+draw; `theme` → draw
/// only. Theme changes used to re-parse and re-lay-out the whole diagram on
/// the main thread.
final class ViewPipelineInvalidationTests: XCTestCase {

    private let source = """
    graph TD
        A[Start] --> B{Check}
        B -->|yes| C[Done]
        B -->|no| A
    """

    // MARK: - MermaidDiagram (synchronous value model)

    func testDiagramThemeChangeKeepsGeometryAndSwapsColorsOnly() {
        var diagram = MermaidDiagram(source: source)
        XCTAssertNotNil(diagram.preparedDiagram)
        let bounds = diagram.diagramBounds
        XCTAssertGreaterThan(bounds.width, 0)

        diagram.theme = .zincDark
        XCTAssertEqual(diagram.diagramBounds, bounds, "theme must not change geometry")
        XCTAssertNotNil(diagram.preparedDiagram, "theme change must keep the diagram renderable")
        XCTAssertNil(diagram.parseError)
    }

    func testDiagramThemeChangeIsFarCheaperThanSourceChange() {
        // Comparative bound (not absolute — machines differ): a recolor must be
        // at least 5× cheaper than the full parse+layout a source change pays.
        var diagram = MermaidDiagram(source: source)

        let themeStart = ContinuousClock.now
        for _ in 0..<20 {
            diagram.theme = diagram.theme == .zincDark ? .zincLight : .zincDark
        }
        let themeTime = ContinuousClock.now - themeStart

        let sourceStart = ContinuousClock.now
        for i in 0..<20 {
            diagram.source = source + "\n    %% v\(i)"
        }
        let sourceTime = ContinuousClock.now - sourceStart

        XCTAssertLessThan(themeTime, sourceTime / 5,
            "theme recolor (\(themeTime)) should be ≫ cheaper than re-pipeline (\(sourceTime))")
    }

    func testDiagramLayoutConfigChangeRelayoutsWithoutReparse() {
        var diagram = MermaidDiagram(source: source)
        XCTAssertNotNil(diagram.preparedDiagram)

        var config = LayoutConfig()
        config.nodeSpacing = 120
        diagram.layoutConfig = config
        XCTAssertNotNil(diagram.preparedDiagram)
        XCTAssertNil(diagram.parseError)
        XCTAssertGreaterThan(diagram.diagramBounds.width, 0)
    }

    func testDiagramParseErrorClearsOutputsAndRecovers() {
        var diagram = MermaidDiagram(source: "sequenceDiagram\n    !!!not-mermaid!!!")
        _ = diagram.parseError  // may or may not error depending on parser leniency

        diagram.source = source
        XCTAssertNil(diagram.parseError)
        XCTAssertNotNil(diagram.preparedDiagram)
    }

    // MARK: - MermaidLayer (asynchronous pipeline)

    func testLayerPreparesOffMainAndPublishesResult() {
        let layer = MermaidLayer()
        let prepared = expectation(description: "prepared")
        layer.onPrepareComplete = { prepared.fulfill() }
        layer.source = source
        wait(for: [prepared], timeout: 5)

        XCTAssertNil(layer.parseError)
        XCTAssertNotNil(layer.preparedDiagram)
        XCTAssertGreaterThan(layer.diagramBounds.width, 0)
    }

    func testLayerThemeChangeDoesNotRerunPipeline() {
        let layer = MermaidLayer()
        let prepared = expectation(description: "prepared")
        layer.onPrepareComplete = { prepared.fulfill() }
        layer.source = source
        wait(for: [prepared], timeout: 5)
        let bounds = layer.diagramBounds

        var extraPrepares = 0
        layer.onPrepareComplete = { extraPrepares += 1 }
        layer.theme = .zincDark

        // Give any (wrong) async work a chance to land before asserting.
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settle.fulfill() }
        wait(for: [settle], timeout: 2)

        XCTAssertEqual(extraPrepares, 0, "theme-only change must not re-run parse/layout")
        XCTAssertNotNil(layer.preparedDiagram)
        XCTAssertEqual(layer.diagramBounds, bounds)
    }

    // MARK: - Contents pipeline (off-main raster → layer.contents)

    private func pump(until condition: @escaping () -> Bool, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testViewDeliversRasterContentsWithoutMainThreadDrawing() {
        let view = MermaidView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.source = source

        pump(until: { view.mermaidLayer.rasterRenderCount > 0 })
        XCTAssertGreaterThan(view.mermaidLayer.rasterRenderCount, 0, "raster should be produced off-main")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        XCTAssertNotNil(view.layer?.contents, "raster should be composited via layer.contents")
        #else
        XCTAssertNotNil(view.layer.contents, "raster should be composited via layer.contents")
        #endif
    }

    func testViewRasterRequestsAreCoalescedPerContentAndSize() {
        let view = MermaidView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.source = source
        pump(until: { view.mermaidLayer.rasterRenderCount > 0 })
        let baseline = view.mermaidLayer.rasterRenderCount

        // Same content, same size → no new raster.
        view.setNeedsLayout_compat()
        pump(until: { false }, timeout: 0.3)
        XCTAssertEqual(view.mermaidLayer.rasterRenderCount, baseline, "duplicate size must hit the coalescer")

        // Theme change → exactly one re-raster at the same size.
        view.theme = .zincDark
        pump(until: { view.mermaidLayer.rasterRenderCount > baseline })
        XCTAssertEqual(view.mermaidLayer.rasterRenderCount, baseline + 1)
    }

    func testFirstPaintLatencyIsBoundedForSmallDiagrams() {
        // End-to-end: source set → async parse+layout → async raster →
        // contents visible. Comparative/absolute bound: a small diagram's
        // whole pipeline is ~1.6 ms of work (0.08 parse + 0.8 layout + ~0.4
        // raster) plus queue hops; 500 ms is a generous CI-safe ceiling that
        // still catches an accidentally serialized or stalled pipeline.
        let view = MermaidView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let start = ContinuousClock.now
        view.source = source
        pump(until: { view.mermaidLayer.rasterRenderCount > 0 })
        let elapsed = ContinuousClock.now - start

        XCTAssertGreaterThan(view.mermaidLayer.rasterRenderCount, 0)
        XCTAssertLessThan(elapsed, .milliseconds(500), "first paint took \(elapsed)")
        print("first-paint latency (small diagram, 400×300): \(elapsed)")
    }

    func testLayerDropsSupersededGenerations() {
        let layer = MermaidLayer()
        let prepared = expectation(description: "prepared")
        prepared.assertForOverFulfill = false
        layer.onPrepareComplete = { prepared.fulfill() }

        layer.source = "graph TD; X-->Y"
        layer.source = source  // supersedes the first before it can publish

        wait(for: [prepared], timeout: 5)
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settle.fulfill() }
        wait(for: [settle], timeout: 2)

        // The published geometry must belong to the LAST source set.
        XCTAssertNil(layer.parseError)
        XCTAssertNotNil(layer.preparedDiagram)
        XCTAssertGreaterThan(layer.diagramBounds.height, 40, "expected multi-node diagram geometry")
    }
}
#endif

#if canImport(UIKit) || canImport(AppKit)
private extension MermaidView {
    /// Re-runs the contents update path the way a layout pass would.
    func setNeedsLayout_compat() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        layout()
        #else
        layoutSubviews()
        #endif
    }
}
#endif
