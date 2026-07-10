// BeautifulMermaid micro-benchmark harness.
//
// Repeatable, release-mode wall-clock benchmark for the parse -> layout -> render
// pipeline. Reports min and median over N timed iterations after a warmup, using a
// monotonic clock. Designed to be diffed across optimization commits.
//
//   swift run -c release bench            # run all workloads
//   swift run -c release bench parse      # filter by stage substring
//
import Foundation
import BeautifulMermaid

// MARK: - Timing

@inline(never)
func timeMedian(_ label: String, warmup: Int, iterations: Int, _ body: () -> Void) {
    for _ in 0..<warmup { body() }
    var samples = [Double](repeating: 0, count: iterations)
    for i in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        samples[i] = Double(end - start) / 1_000_000.0 // ms
    }
    samples.sort()
    let median = samples[iterations / 2]
    let min = samples[0]
    let p95 = samples[Int(Double(iterations) * 0.95)]
    print(String(format: "%-38s  min %8.3f ms   median %8.3f ms   p95 %8.3f ms", (label as NSString).utf8String!, min, median, p95))
}

// MARK: - Workloads

let flowchart = """
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Do Something]
    B -->|No| D[Do Something Else]
    C --> E[End]
    D --> E
"""

let flowchartComplex = """
graph TD
    A[Client Request] --> B{Auth Valid?}
    B -->|Yes| C[Load Balancer]
    B -->|No| Z[401 Unauthorized]
    C --> D[Service A]
    C --> E[Service B]
    C --> F[Service C]
    D --> G[(Database)]
    E --> G
    F --> H[(Cache)]
    G --> I[Response Builder]
    H --> I
    I --> J[Client Response]
    Z --> J
"""

let sequence = """
sequenceDiagram
    participant U as User
    participant A as API
    participant D as Database
    U->>A: POST /login
    A->>D: SELECT user
    D-->>A: user row
    A-->>U: 200 OK + token
    U->>A: GET /profile
    A->>D: SELECT profile
    D-->>A: profile
    A-->>U: 200 OK
"""

let classDiagram = """
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() void
    }
    class Dog {
        +String breed
        +bark() void
    }
    class Cat {
        +bool indoor
        +meow() void
    }
    Animal <|-- Dog
    Animal <|-- Cat
"""

let erDiagram = """
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    CUSTOMER {
        string name
        string email
    }
    ORDER {
        int id
        date created
    }
    LINE_ITEM {
        int quantity
        float price
    }
"""

let xychart = """
xychart-beta
    title "Revenue"
    x-axis [jan, feb, mar, apr, may, jun]
    y-axis "Revenue ($)" 0 --> 10000
    bar [5000, 6000, 7500, 8200, 9100, 9800]
    line [5000, 6000, 7500, 8200, 9100, 9800]
"""

// Synthetic large flowchart to stress layout (network simplex, crossing min, etc.)
func makeLargeFlowchart(nodes: Int) -> String {
    var s = "graph TD\n"
    for i in 0..<nodes {
        s += "    N\(i)[Node \(i) with a moderately long label]\n"
    }
    // Layered edges: each node points to two nodes further down, forming a DAG.
    for i in 0..<nodes {
        let a = i + 1
        let b = i + 3
        if a < nodes { s += "    N\(i) --> N\(a)\n" }
        if b < nodes { s += "    N\(i) --> N\(b)\n" }
    }
    return s
}

let large = makeLargeFlowchart(nodes: 80)

let filter = CommandLine.arguments.dropFirst().first

// Tight render loop for the macOS `sample` profiler: attribute the ASCII render
// cost to functions. `.build/release/bench profileloop &` then `sample <pid>`.
if filter == "profileloop" {
    print("profiling renderASCII(large-80) in a loop — sample this pid then kill it")
    while true {
        _ = try? MermaidRenderer.renderASCII(source: large)
    }
}

// Same, for the layout stage (the ELK pipeline). The autoreleasepool matches
// real callers (apps drain per runloop turn); without it, Foundation-bridged
// temporaries accumulate forever in this endless loop and mask leak signals.
if filter == "profilelayout" {
    print("profiling layout(large-80) in a loop — sample this pid then kill it")
    while true {
        autoreleasepool {
            _ = try? MermaidRenderer.layout(large)
        }
    }
}

func shouldRun(_ label: String) -> Bool {
    guard let f = filter else { return true }
    return label.lowercased().contains(f.lowercased())
}

#if canImport(UIKit) || canImport(AppKit)
// Block-editor scenario: one document, N diagram blocks, each backed by a
// MermaidLayer sharing the prepare pipeline. Measures what an editor feels:
//
//   cold-load       open a doc with N blocks: time to first raster (something
//                   visible) and to last raster (doc fully rendered)
//   keystroke idle  edit one block in an otherwise settled doc: e2e latency
//                   from source-set to delivered raster
//   keystroke busy  edit block 0 while the other N-1 blocks are still
//                   preparing (typing during document open) — exposes
//                   head-of-line blocking in the shared pipeline
//   memory          phys_footprint with N live prepared+rastered layers
//
// Runs on the main thread; deliveries arrive via the main runloop, so we pump
// it in 1 ms slices while waiting (adds ≤~1 ms noise per wait).
//
// Memory is a separate mode (`bench blockeditor-mem <n>`): footprint must be
// measured on first touch in a cold process — successive in-process runs reuse
// warm allocator pages and undercount by 3-20x.
if filter == "blockeditor" || filter == "blockeditor-mem" {
    func physFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }

    func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000.0 }

    /// Pumps the main runloop until `done()` or timeout. Returns false on timeout.
    @discardableResult
    func pump(timeout: Double, until done: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() {
            if Date() > deadline { return false }
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.001))
        }
        return true
    }

    /// A realistic mixed document: mostly small/medium blocks, one large per 16.
    func makeDocument(_ n: Int) -> [String] {
        (0..<n).map { i in
            switch i % 16 {
            case 0: return large
            case 1, 5, 9: return flowchartComplex
            case 2, 10: return sequence
            case 3: return classDiagram
            case 6: return erDiagram
            case 7, 11: return xychart
            default: return flowchart
            }
        }
    }

    /// Editor-realistic raster size: fit to a 700 pt content column at 2x.
    func rasterSize(for layer: MermaidLayer) -> CGSize {
        let b = layer.diagramBounds
        guard b.width > 0, b.height > 0 else { return CGSize(width: 2, height: 2) }
        let fit = min(1.0, 700.0 / b.width)
        return CGSize(width: b.width * fit * 2, height: b.height * fit * 2)
    }

    final class Block {
        let layer = MermaidLayer()
        var delivered = 0
        var lastDeliveryAt: Double = 0
        /// Retained like a real editor retains `layer.contents` — the raster
        /// pixels are the dominant per-block memory cost, so dropping them
        /// here would make the footprint numbers meaningless.
        var image: CGImage?
        init() {
            layer.onPrepareComplete = { [weak self] in
                guard let self else { return }
                self.layer.requestRaster(pixelSize: rasterSize(for: self.layer)) { img in
                    self.image = img
                    self.delivered += 1
                    self.lastDeliveryAt = now()
                }
            }
        }
    }

    let cores = ProcessInfo.processInfo.activeProcessorCount

    if filter == "blockeditor-mem" {
        let n = Int(CommandLine.arguments.dropFirst(2).first ?? "") ?? 24
        let sources = makeDocument(n)
        let memBefore = physFootprintMB()
        let blocks = (0..<n).map { _ in Block() }
        for (i, block) in blocks.enumerated() { block.layer.source = sources[i] }
        pump(timeout: 60) { blocks.allSatisfy { $0.delivered >= 1 } }
        let live = physFootprintMB()
        print(String(format: "doc n=%-3d | live footprint %7.1f MB   doc cost +%6.1f MB (%.2f MB/block)",
                     n, live, live - memBefore, (live - memBefore) / Double(n)))
        withExtendedLifetime(blocks) {}
        exit(0)
    }

    print("== block-editor scenario ==  (\(cores) cores)")

    for n in [8, 24, 64] {
        let sources = makeDocument(n)

        // --- cold load: median of 3 runs ---
        var firsts: [Double] = [], lasts: [Double] = []
        for _ in 0..<3 {
            autoreleasepool {
                let blocks = (0..<n).map { _ in Block() }
                let t0 = now()
                for (i, block) in blocks.enumerated() { block.layer.source = sources[i] }
                pump(timeout: 60) { blocks.allSatisfy { $0.delivered >= 1 } }
                let deliveries = blocks.map { $0.lastDeliveryAt }
                firsts.append(deliveries.min()! - t0)
                lasts.append(deliveries.max()! - t0)
                // Blocks release here; queued work has fully drained (all delivered).
            }
        }
        firsts.sort(); lasts.sort()
        print(String(format: "doc n=%-3d | cold first %8.1f ms   all %8.1f ms",
                     n, firsts[1], lasts[1]))

        // --- keystroke latency, idle document ---
        autoreleasepool {
            let blocks = (0..<n).map { _ in Block() }
            for (i, block) in blocks.enumerated() { block.layer.source = sources[i] }
            pump(timeout: 60) { blocks.allSatisfy { $0.delivered >= 1 } }

            let editable = blocks[0]
            var latencies: [Double] = []
            for k in 0..<15 {
                let before = editable.delivered
                let t0 = now()
                editable.layer.source = flowchartComplex + "\n    K\(k)[typed \(k)]"
                pump(timeout: 30) { editable.delivered > before }
                latencies.append(now() - t0)
            }
            latencies.sort()
            print(String(format: "doc n=%-3d | keystroke idle  median %6.1f ms   p95 %6.1f ms",
                         n, latencies[latencies.count / 2], latencies[Int(Double(latencies.count) * 0.95)]))
        }

        // --- keystroke during cold-load storm: median of 3 runs ---
        var busy: [Double] = []
        for _ in 0..<3 {
            autoreleasepool {
                let blocks = (0..<n).map { _ in Block() }
                // Storm: blocks 1..n-1 start preparing…
                for i in 1..<n { blocks[i].layer.source = sources[i] }
                // …and the user types into block 0 immediately after.
                let before = blocks[0].delivered
                let t0 = now()
                blocks[0].layer.source = flowchartComplex + "\n    T[typed during load]"
                pump(timeout: 60) { blocks[0].delivered > before }
                busy.append(now() - t0)
                // Drain the storm fully before the next run.
                pump(timeout: 60) { blocks.allSatisfy { $0.delivered >= 1 } }
            }
        }
        busy.sort()
        print(String(format: "doc n=%-3d | keystroke busy  median %6.1f ms  (typing while doc opens)", n, busy[1]))
        print("")
    }
    exit(0)
}
#endif

// MARK: - Run

struct Case { let name: String; let source: String; let heavyIters: Int }
let cases: [Case] = [
    Case(name: "flowchart-small", source: flowchart, heavyIters: 200),
    Case(name: "flowchart-complex", source: flowchartComplex, heavyIters: 100),
    Case(name: "sequence", source: sequence, heavyIters: 150),
    Case(name: "class", source: classDiagram, heavyIters: 150),
    Case(name: "er", source: erDiagram, heavyIters: 150),
    Case(name: "xychart", source: xychart, heavyIters: 150),
    Case(name: "flowchart-large-80", source: large, heavyIters: 30),
]

print("== BeautifulMermaid benchmark ==  (\(ProcessInfo.processInfo.activeProcessorCount) cores)")
print("")

for c in cases {
    let src = c.source
    if shouldRun("\(c.name) parse") {
        timeMedian("\(c.name) | parse", warmup: 20, iterations: max(c.heavyIters * 3, 100)) {
            _ = try? MermaidRenderer.parse(src)
        }
    }
    if shouldRun("\(c.name) layout") {
        timeMedian("\(c.name) | layout", warmup: 10, iterations: c.heavyIters) {
            _ = try? MermaidRenderer.layout(src)
        }
    }
    if shouldRun("\(c.name) svg") {
        timeMedian("\(c.name) | renderSVG", warmup: 10, iterations: c.heavyIters) {
            _ = try? MermaidRenderer.renderSVG(source: src)
        }
    }
    if shouldRun("\(c.name) ascii") {
        timeMedian("\(c.name) | renderASCII", warmup: 5, iterations: max(c.heavyIters / 3, 10)) {
            _ = try? MermaidRenderer.renderASCII(source: src)
        }
    }
    #if canImport(UIKit) || canImport(AppKit)
    // Theme recolor cost: after staged invalidation this is all a theme
    // change pays (renderer rebuild + closure swap; drawing re-runs on the
    // next display pass, which renderImage below already measures).
    if shouldRun("\(c.name) themeswitch") {
        timeMedian("\(c.name) | themeSwitch", warmup: 50, iterations: 2000) {
            let renderer = DiagramRenderer(theme: .zincDark)
            _ = renderer
        }
    }
    // Native CoreGraphics rendering (the iOS/macOS in-app path).
    // `renderImage(from: positioned)` isolates draw + bitmap cost from
    // parse/layout; `renderImage(from: source)` is the end-to-end app cost.
    if shouldRun("\(c.name) image"), let positioned = try? MermaidRenderer.layout(src) {
        let imageRenderer = MermaidImageRenderer()
        timeMedian("\(c.name) | renderImage", warmup: 5, iterations: max(c.heavyIters / 2, 20)) {
            autoreleasepool {
                _ = imageRenderer.renderImage(from: positioned)
            }
        }
    }
    #endif
    print("")
}

#if canImport(UIKit) || canImport(AppKit)
import CoreGraphics
// Steady-state view redraw: vector replay vs cached-raster blit (ledger #33).
if filter == "viewblit" {
    for (name, src) in [("small", flowchart), ("large-80", large)] {
        let renderer = MermaidImageRenderer()
        guard let prepared = try? renderer.prepare(from: src) else { continue }
        let b = prepared.bounds
        let scale: CGFloat = 2
        let w = Int(b.width * scale), h = Int(b.height * scale)
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let target = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                     bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
        else { continue }

        timeMedian("\(name) | redraw vector", warmup: 5, iterations: 60) {
            target.saveGState()
            target.scaleBy(x: scale, y: scale)
            prepared.render(target, b)
            target.restoreGState()
        }

        guard let rasterCtx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
        else { continue }
        rasterCtx.scaleBy(x: scale, y: scale)
        prepared.render(rasterCtx, b)
        guard let image = rasterCtx.makeImage() else { continue }
        let rect = CGRect(x: 0, y: 0, width: b.width * scale, height: b.height * scale)
        timeMedian("\(name) | redraw blit", warmup: 5, iterations: 200) {
            target.interpolationQuality = .none
            target.draw(image, in: rect)
        }
        timeMedian("\(name) | redraw blit 0.8x", warmup: 5, iterations: 60) {
            target.interpolationQuality = .default
            target.draw(image, in: CGRect(x: 0, y: 0, width: rect.width * 0.8, height: rect.height * 0.8))
        }

        // Main-thread cost of today's draw(_:) at realistic VIEW sizes
        // (fit-scaled), which is what a window actually pays per invalidation.
        for fit in [0.15, 0.5, 1.0] {
            let vw = Int(b.width * fit * scale), vh = Int(b.height * fit * scale)
            guard vw > 0, vh > 0,
                  let viewCtx = CGContext(data: nil, width: vw, height: vh, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
            else { continue }
            timeMedian("\(name) | view draw fit=\(fit)", warmup: 5, iterations: 60) {
                viewCtx.saveGState()
                viewCtx.scaleBy(x: fit * scale, y: fit * scale)
                prepared.render(viewCtx, b)
                viewCtx.restoreGState()
            }
        }
    }
    exit(0)
}
#endif

// Tight SVG-string loop for the macOS `sample` profiler.
if filter == "profilesvg" {
    print("profiling renderSVG(large-80) in a loop — sample this pid then kill it")
    while true {
        autoreleasepool {
            _ = try? MermaidRenderer.renderSVG(source: large)
        }
    }
}

// Tight native-render loop for the macOS `sample` profiler.
if filter == "profileimage" {
    print("profiling renderImage(large-80) in a loop — sample this pid then kill it")
    let positioned = try! MermaidRenderer.layout(large)
    let imageRenderer = MermaidImageRenderer()
    while true {
        autoreleasepool {
            _ = imageRenderer.renderImage(from: positioned)
        }
    }
}
