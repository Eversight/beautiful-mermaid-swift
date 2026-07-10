import XCTest
@testable import BeautifulMermaid

#if canImport(UIKit) || canImport(AppKit)
import QuartzCore
#endif

/// Guards the concurrent prepare pipeline (MermaidLayer's bounded-width pool)
/// and the engine's public thread-safety contract: `parse`/`layout`/`renderSVG`
/// are callable from any thread, concurrently, with deterministic results.
final class ConcurrentPrepareStressTests: XCTestCase {

    static let sources: [String] = [
        """
        graph TD
            A[Start] --> B{Decision}
            B -->|Yes| C[Do Something]
            B -->|No| D[Do Something Else]
            C --> E[End]
            D --> E
        """,
        """
        sequenceDiagram
            participant U as User
            participant A as API
            U->>A: POST /login
            A-->>U: 200 OK
        """,
        """
        classDiagram
            class Animal {
                +String name
                +makeSound() void
            }
            Animal <|-- Dog
        """,
        """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER {
                int id
            }
        """,
        """
        xychart-beta
            title "Revenue"
            x-axis [jan, feb, mar]
            y-axis "Revenue" 0 --> 100
            bar [10, 40, 90]
        """,
        """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Running : start
            Running --> Idle : stop
        """,
    ]

    /// The full pipeline must produce byte-identical output no matter how many
    /// threads run it at once (the layout engine shares metadata singletons and
    /// instance pools internally — all Mutex-guarded; this is the empirical
    /// gate, and the TSan target for data-race detection).
    func testConcurrentRenderDeterminism() throws {
        let sources = Self.sources
        let references = try sources.map { try MermaidRenderer.renderSVG(source: $0) }

        let iterations = 96
        var results = [String?](repeating: nil, count: iterations)
        results.withUnsafeMutableBufferPointer { buffer in
            let base = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: iterations) { i in
                // Each iteration writes only its own slot — no shared mutation.
                base[i] = try? MermaidRenderer.renderSVG(source: sources[i % sources.count])
            }
        }

        for (i, svg) in results.enumerated() {
            XCTAssertEqual(svg, references[i % sources.count],
                           "concurrent render #\(i) diverged from serial reference")
        }
    }

    /// Concurrent layouts unboxing the *same* parsed value must not interfere:
    /// this is exactly what MermaidLayer does when `layoutConfig` changes while
    /// a previous layout of the same parsed graph is still in flight.
    func testConcurrentLayoutOfSharedParse() throws {
        let graph = try MermaidRenderer.parse(Self.sources[0])
        let reference = try GraphLayout(config: LayoutConfig()).layout(graph)

        let iterations = 48
        var widths = [Double](repeating: -1, count: iterations)
        widths.withUnsafeMutableBufferPointer { buffer in
            let base = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: iterations) { i in
                base[i] = (try? GraphLayout(config: LayoutConfig()).layout(graph))?.width ?? -1
            }
        }
        for w in widths {
            XCTAssertEqual(w, reference.width, accuracy: 0.0001)
        }
    }

    #if canImport(UIKit) || canImport(AppKit)

    /// A document's worth of layers all preparing at once: every one must
    /// deliver a raster (no lost completions, no deadlock at pool width).
    func testLayerStormAllDeliver() {
        let n = 32
        var layers: [MermaidLayer] = []
        var delivered = 0
        let all = expectation(description: "all rasters delivered")

        for i in 0..<n {
            let layer = MermaidLayer()
            layer.onPrepareComplete = { [weak layer] in
                guard let layer, layer.parseError == nil else {
                    XCTFail("prepare failed"); return
                }
                layer.requestRaster(pixelSize: CGSize(width: 200, height: 150)) { _ in
                    delivered += 1
                    if delivered == n { all.fulfill() }
                }
            }
            layers.append(layer)
            layer.source = Self.sources[i % Self.sources.count]
        }

        wait(for: [all], timeout: 30)
        for layer in layers {
            XCTAssertGreaterThan(layer.diagramBounds.width, 0)
        }
    }

    /// Rapid supersession: with a concurrent pool, an older (slower) prepare
    /// can finish *after* a newer one. The generation guard must ensure the
    /// layer settles on the LAST source, never a stale one.
    func testSupersessionSettlesOnLastSource() throws {
        let small = Self.sources[0]
        var big = "graph TD\n"
        for i in 0..<60 {
            big += "    N\(i)[Node \(i)]\n"
            if i > 0 { big += "    N\(i - 1) --> N\(i)\n" }
        }

        let expectedBounds = try GraphLayout(config: LayoutConfig()).layout(MermaidRenderer.parse(small))

        let layer = MermaidLayer()
        var fulfilled = false
        let settled = expectation(description: "settled")
        layer.onPrepareComplete = {
            // Superseded generations never publish, so this normally fires
            // exactly once (for the last source). Give any stale in-flight
            // work time to land — the generation guard must drop it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !fulfilled { fulfilled = true; settled.fulfill() }
            }
        }

        // Interleave big (slow) and small (fast) sources; last one wins.
        layer.source = big
        layer.source = small
        layer.source = big
        layer.source = small

        wait(for: [settled], timeout: 30)
        XCTAssertEqual(layer.diagramBounds.width, CGFloat(max(1, expectedBounds.width)), accuracy: 0.0001,
                       "layer must settle on the geometry of the LAST source set")
    }

    #endif
}
