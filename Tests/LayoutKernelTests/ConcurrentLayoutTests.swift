import XCTest
@testable import LayoutKernel

final class ConcurrentLayoutTests: XCTestCase {

    // MARK: - Test Graphs

    private static let flow18Json = """
    {"children":[{"id":"E","labels":[{"text":"Deploy Staging"}],"width":130.129,"height":36.9},{"id":"F","labels":[{"text":"QA Approved?"}],"width":152.647,"height":152.647},{"id":"G","labels":[{"text":"Production"}],"width":122,"height":122},{"children":[{"id":"A","labels":[{"text":"Push Code"}],"width":106.417,"height":36.9},{"id":"B","labels":[{"text":"Tests Pass?"}],"width":140.791,"height":140.791},{"id":"C","labels":[{"text":"Build Image"}],"width":107.899,"height":36.9},{"id":"D","labels":[{"text":"Fix & Retry"}],"width":105.676,"height":36.9}],"edges":[{"id":"e0","sources":["A"],"targets":["B"]},{"id":"e1","labels":[{"layoutOptions":{"elk.edgeLabels.inline":"true","elk.edgeLabels.placement":"CENTER"},"text":"Yes","width":28.658,"height":20.3}],"sources":["B"],"targets":["C"]},{"id":"e2","labels":[{"layoutOptions":{"elk.edgeLabels.inline":"true","elk.edgeLabels.placement":"CENTER"},"text":"No","width":22.718,"height":20.3}],"sources":["B"],"targets":["D"]},{"id":"e3","sources":["D"],"targets":["A"]}],"id":"ci","labels":[{"text":"CI Pipeline"}],"layoutOptions":{"elk.algorithm":"layered","elk.contentAlignment":"H_CENTER V_CENTER","elk.edgeRouting":"ORTHOGONAL","elk.layered.nodePlacement.bk.fixedAlignment":"BALANCED","elk.layered.spacing.edgeEdgeBetweenLayers":"12","elk.layered.spacing.edgeNodeBetweenLayers":"12","elk.layered.spacing.nodeNodeBetweenLayers":"48","elk.padding":"[top=44,left=16,bottom=16,right=16]","elk.spacing.edgeEdge":"12","elk.spacing.nodeNode":"28"}}],"edges":[{"id":"e4","sources":["C"],"targets":["E"]},{"id":"e5","sources":["E"],"targets":["F"]},{"id":"e6","labels":[{"layoutOptions":{"elk.edgeLabels.inline":"true","elk.edgeLabels.placement":"CENTER"},"text":"Yes","width":28.658,"height":20.3}],"sources":["F"],"targets":["G"]},{"id":"e7","labels":[{"layoutOptions":{"elk.edgeLabels.inline":"true","elk.edgeLabels.placement":"CENTER"},"text":"No","width":22.718,"height":20.3}],"sources":["F"],"targets":["D"]}],"id":"root","layoutOptions":{"elk.algorithm":"layered","elk.contentAlignment":"H_CENTER V_CENTER","elk.direction":"DOWN","elk.edgeRouting":"ORTHOGONAL","elk.hierarchyHandling":"INCLUDE_CHILDREN","elk.layered.compaction.postCompaction.strategy":"LEFT_RIGHT_CONSTRAINT_LOCKING","elk.layered.considerModelOrder.strategy":"NODES_AND_EDGES","elk.layered.highDegreeNodes.threshold":"8","elk.layered.highDegreeNodes.treatment":"true","elk.layered.nodePlacement.bk.fixedAlignment":"BALANCED","elk.layered.spacing.edgeEdgeBetweenLayers":"12","elk.layered.spacing.edgeNodeBetweenLayers":"12","elk.layered.spacing.nodeNodeBetweenLayers":"48","elk.layered.thoroughness":"3","elk.layered.wrapping.strategy":"OFF","elk.padding":"[top=40,left=40,bottom=40,right=40]","elk.spacing.edgeEdge":"12","elk.spacing.nodeNode":"28"}}
    """

    private static func simpleChainGraph() -> [String: Any] {
        [
            "id": "root",
            "layoutOptions": ["elk.algorithm": "layered", "elk.direction": "RIGHT"],
            "children": [
                ["id": "A", "width": 50, "height": 30],
                ["id": "B", "width": 50, "height": 30],
                ["id": "C", "width": 50, "height": 30]
            ],
            "edges": [
                ["id": "e1", "sources": ["A"], "targets": ["B"]],
                ["id": "e2", "sources": ["B"], "targets": ["C"]]
            ]
        ] as [String: Any]
    }

    private static func diamondGraph() -> [String: Any] {
        [
            "id": "root",
            "layoutOptions": ["elk.algorithm": "layered", "elk.direction": "DOWN"],
            "children": [
                ["id": "A", "width": 60, "height": 40],
                ["id": "B", "width": 60, "height": 40],
                ["id": "C", "width": 60, "height": 40],
                ["id": "D", "width": 60, "height": 40]
            ],
            "edges": [
                ["id": "e1", "sources": ["A"], "targets": ["B"]],
                ["id": "e2", "sources": ["A"], "targets": ["C"]],
                ["id": "e3", "sources": ["B"], "targets": ["D"]],
                ["id": "e4", "sources": ["C"], "targets": ["D"]]
            ]
        ] as [String: Any]
    }

    private static func parseJson(_ json: String) throws -> [String: Any] {
        let data = json.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: - Tests

    func testConcurrentLayoutsProduceSameResults() throws {
        let graph = try Self.parseJson(Self.flow18Json)

        // Run 10x serially to get baseline
        var baselineResults: [Data] = []
        for _ in 0..<10 {
            let elk = LayoutEngine()
            let result = try elk.layout(graph: graph)
            let data = try JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
            baselineResults.append(data)
        }

        // All serial results should be identical
        let baselineData = baselineResults[0]
        for (i, data) in baselineResults.enumerated() {
            XCTAssertEqual(data, baselineData, "Serial run \(i) differs from baseline")
        }

        // Run 10x concurrently
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var concurrentResults: [Data] = []
        var concurrentErrors: [Swift.Error] = []

        for _ in 0..<10 {
            group.enter()
            concurrentQueue.async {
                do {
                    let elk = LayoutEngine()
                    let result = try elk.layout(graph: graph)
                    let data = try JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
                    lock.lock()
                    concurrentResults.append(data)
                    lock.unlock()
                } catch {
                    lock.lock()
                    concurrentErrors.append(error)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.wait()
        XCTAssertTrue(concurrentErrors.isEmpty, "Concurrent errors: \(concurrentErrors)")
        XCTAssertEqual(concurrentResults.count, 10)

        for (i, data) in concurrentResults.enumerated() {
            XCTAssertEqual(data, baselineData, "Concurrent run \(i) differs from serial baseline")
        }
    }

    func testConcurrentLayoutsNoCrash() throws {
        let graphs: [[String: Any]] = [
            Self.simpleChainGraph(),
            Self.diamondGraph(),
            try Self.parseJson(Self.flow18Json)
        ]

        let concurrentQueue = DispatchQueue(label: "test.concurrent.nocrash", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var errors: [Swift.Error] = []

        for i in 0..<20 {
            group.enter()
            concurrentQueue.async {
                do {
                    let elk = LayoutEngine()
                    let graph = graphs[i % graphs.count]
                    let result = try elk.layout(graph: graph)
                    // Verify result has non-zero dimensions
                    if let children = result["children"] as? [[String: Any]] {
                        for child in children {
                            if let x = child["x"] as? Double, let y = child["y"] as? Double {
                                XCTAssertTrue(x.isFinite, "Node x is not finite")
                                XCTAssertTrue(y.isFinite, "Node y is not finite")
                            }
                        }
                    }
                } catch {
                    lock.lock()
                    errors.append(error)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.wait()
        XCTAssertTrue(errors.isEmpty, "Concurrent errors: \(errors)")
    }

    func testConcurrentInitNoCrash() throws {
        let concurrentQueue = DispatchQueue(label: "test.concurrent.init", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var errors: [Swift.Error] = []
        var instances: [LayoutEngine] = []

        for _ in 0..<10 {
            group.enter()
            concurrentQueue.async {
                do {
                    let elk = LayoutEngine()
                    lock.lock()
                    instances.append(elk)
                    lock.unlock()
                } catch {
                    lock.lock()
                    errors.append(error)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.wait()
        XCTAssertTrue(errors.isEmpty, "Init errors: \(errors)")
        XCTAssertEqual(instances.count, 10)
    }

    // MARK: - High-pressure stress tests
    //
    // The original tests used DispatchQueue.async with only 10 iterations, which
    // rarely reproduced the LayoutMetaDataService.algorithmSuffixMap race that
    // crashed production. These tests raise the pressure by
    //   (a) using concurrentPerform for true parallelism scaled to cpu count,
    //   (b) driving hundreds of iterations per run,
    //   (c) varying the graph corpus so many distinct suffixes get looked up
    //       (each one opens its own first-write cache-miss window).
    //
    // A full cold-start-per-batch would be a stronger net, but it requires
    // pairing LayoutMetaDataService.unload() with a reset of
    // ELK._algorithmsRegistered — a source-side change. Tracked as a follow-up;
    // the pressure tests below are best-effort within the test target alone.

    private static func makeGraphCorpus() -> [[String: Any]] {
        // Each graph sets a different elk.algorithm / edgeRouting / direction
        // combination so the resolver touches a range of suffixes.
        var corpus: [[String: Any]] = []
        let directions = ["RIGHT", "DOWN", "LEFT", "UP"]
        let routings = ["ORTHOGONAL", "POLYLINE"]
        for (i, direction) in directions.enumerated() {
            for routing in routings {
                corpus.append([
                    "id": "root_\(i)_\(routing)",
                    "layoutOptions": [
                        "elk.algorithm": "layered",
                        "elk.direction": direction,
                        "elk.edgeRouting": routing,
                        "elk.spacing.nodeNode": "20"
                    ],
                    "children": [
                        ["id": "A", "width": 50, "height": 30],
                        ["id": "B", "width": 50, "height": 30],
                        ["id": "C", "width": 50, "height": 30],
                        ["id": "D", "width": 50, "height": 30]
                    ],
                    "edges": [
                        ["id": "e1", "sources": ["A"], "targets": ["B"]],
                        ["id": "e2", "sources": ["A"], "targets": ["C"]],
                        ["id": "e3", "sources": ["B"], "targets": ["D"]],
                        ["id": "e4", "sources": ["C"], "targets": ["D"]]
                    ]
                ])
            }
        }
        return corpus
    }

    /// Drives concurrentPerform hard across a diverse corpus. If concurrent
    /// access to the metadata singleton is unsafe, this will either crash
    /// (Dictionary race → EXC_BAD_ACCESS) or report errors from corrupted state.
    func testHighConcurrencyStress() throws {
        let corpus = Self.makeGraphCorpus()
        let workers = max(8, ProcessInfo.processInfo.activeProcessorCount * 2)
        let batches = 40

        let errorsLock = NSLock()
        var errors: [Swift.Error] = []

        for batch in 0..<batches {
            DispatchQueue.concurrentPerform(iterations: workers) { idx in
                do {
                    let elk = LayoutEngine()
                    let graph = corpus[(batch &+ idx) % corpus.count]
                    _ = try elk.layout(graph: graph)
                } catch {
                    errorsLock.lock()
                    errors.append(error)
                    errorsLock.unlock()
                }
            }
        }

        XCTAssertTrue(
            errors.isEmpty,
            "Stress run produced \(errors.count) errors: \(errors.prefix(3))"
        )
    }

    /// Large single-phase burst: 500 concurrent layouts on the same process.
    func testWarmCacheBurst() throws {
        let corpus = Self.makeGraphCorpus()
        let iterations = 500

        let errorsLock = NSLock()
        var errors: [Swift.Error] = []

        DispatchQueue.concurrentPerform(iterations: iterations) { idx in
            do {
                let elk = LayoutEngine()
                let graph = corpus[idx % corpus.count]
                _ = try elk.layout(graph: graph)
            } catch {
                errorsLock.lock()
                errors.append(error)
                errorsLock.unlock()
            }
        }

        XCTAssertTrue(
            errors.isEmpty,
            "Warm-cache burst produced \(errors.count) errors: \(errors.prefix(3))"
        )
    }

    /// Determinism check: N concurrent renders of the same graph must each
    /// equal the serial baseline. Guards against a passing-but-silently-wrong
    /// outcome where a reader sees torn state that doesn't crash.
    func testConcurrentDeterminism() throws {
        let graph = try Self.parseJson(Self.flow18Json)

        let baseline = try JSONSerialization.data(
            withJSONObject: try LayoutEngine().layout(graph: graph),
            options: .sortedKeys
        )

        let workers = max(8, ProcessInfo.processInfo.activeProcessorCount * 2)
        let resultsLock = NSLock()
        var results: [Data] = []
        var errors: [Swift.Error] = []

        for _ in 0..<10 {
            DispatchQueue.concurrentPerform(iterations: workers) { _ in
                do {
                    let out = try LayoutEngine().layout(graph: graph)
                    let data = try JSONSerialization.data(withJSONObject: out, options: .sortedKeys)
                    resultsLock.lock()
                    results.append(data)
                    resultsLock.unlock()
                } catch {
                    resultsLock.lock()
                    errors.append(error)
                    resultsLock.unlock()
                }
            }
        }

        XCTAssertTrue(errors.isEmpty, "Errors during determinism stress: \(errors.prefix(3))")
        for (i, data) in results.enumerated() {
            XCTAssertEqual(data, baseline, "Concurrent run \(i) diverged from serial baseline")
        }
    }

    func testLayoutTimeout() throws {
        let graph = try Self.parseJson(Self.flow18Json)
        let elk = LayoutEngine()

        // timeout: 0 means deadline == now, so isCanceled() is true on the first check.
        XCTAssertThrowsError(try elk.layout(graph: graph, timeout: 0)) { error in
            guard let elkError = error as? LayoutEngine.Error else {
                XCTFail("Expected LayoutEngine.Error, got \(type(of: error))")
                return
            }
            if case .timedOut = elkError {
                // Expected
            } else {
                XCTFail("Expected .timedOut, got \(elkError)")
            }
        }
    }
}
