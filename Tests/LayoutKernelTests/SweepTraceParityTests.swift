import XCTest
@testable import LayoutKernel

/// Harness validation for the S2' differential trace (`SweepTrace`).
///
/// Until the flat engine exists this asserts the property the differential
/// method rests on: two runs over the same graph shape with the same seed
/// produce byte-identical decision traces. Once the flat engine lands, the
/// same machinery compares object-vs-flat traces and the first divergence
/// pinpoints the first wrong decision (see docs/SweepEngineContract.md §7).
final class SweepTraceParityTests: XCTestCase {

    override func tearDown() {
        LayerSweepCrossingMinimizer.trace = nil
        super.tearDown()
    }

    /// Runs the barycenter minimizer over a fresh copy of the three-layer
    /// crossing graph with the production LCG (`Random(seed: 1)`), tracing
    /// every sweep decision.
    private func runTraced() -> SweepTrace {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        let graph = creator.getGraph()
        // Replace the creator's MockRandom with the production 48-bit LCG so
        // the trace exercises the real random stream the parity work targets.
        graph.setProperty(InternalProperties.RANDOM, Random(seed: 1))

        let trace = SweepTrace()
        LayerSweepCrossingMinimizer.trace = trace
        defer { LayerSweepCrossingMinimizer.trace = nil }

        LayerSweepCrossingMinimizer(.BARYCENTER).process(graph, BasicProgressMonitor())
        return trace
    }

    func testTraceIsDeterministicAcrossRuns() {
        let first = runTraced()
        let second = runTraced()

        XCTAssertFalse(first.events.isEmpty, "trace must capture sweep decisions")
        if let divergence = SweepTrace.firstDivergence(first, second) {
            XCTFail("""
            traces diverge at event \(divergence):
              run1: \(first.events[divergence])
              run2: \(second.events[divergence])
            """)
        }
        XCTAssertEqual(first.events.count, second.events.count)
    }

    func testTraceCapturesAllDecisionKinds() {
        let trace = runTraced()
        let kinds = Set(trace.events.map { event -> String in
            switch event {
            case .tryStart: return "tryStart"
            case .layerOrder: return "layerOrder"
            case .portOrder: return "portOrder"
            case .count: return "count"
            case .snapshotBest: return "snapshotBest"
            case .saveBest: return "saveBest"
            }
        })
        // The barycenter path on a graph with crossings must exercise every
        // decision kind the differential relies on (portOrder appears only
        // when port order is not fixed, which this graph provides).
        for expected in ["tryStart", "layerOrder", "count", "snapshotBest", "saveBest"] {
            XCTAssertTrue(kinds.contains(expected), "trace never recorded \(expected)")
        }
    }
}
