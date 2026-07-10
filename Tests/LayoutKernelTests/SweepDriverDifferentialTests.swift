import XCTest
@testable import LayoutKernel

/// The S2' end-to-end differential (contract §7): the object
/// `LayerSweepCrossingMinimizer.process` and the flat `SweepEngine` driver run
/// full crossing minimization on identically-built graphs with the same seed.
/// Every traced decision (try directions, per-layer orders, port orders,
/// counts, snapshots) must be identical, and the transferred graphs must
/// end in the same state.
final class SweepDriverDifferentialTests: XCTestCase {

    override func tearDown() {
        LayerSweepCrossingMinimizer.trace = nil
        super.tearDown()
    }

    /// Stable node labels (layer, position at build time) surviving the
    /// transfer's `node.id` rewrite.
    private func labelMap(_ graph: LGraph) -> [ObjectIdentifier: Int] {
        var labels = [ObjectIdentifier: Int]()
        for (l, layer) in graph.getLayers().enumerated() {
            for (i, node) in layer.getNodes().enumerated() {
                labels[ObjectIdentifier(node)] = l * 1000 + i
            }
        }
        return labels
    }

    private func finalState(_ graph: LGraph, _ labels: [ObjectIdentifier: Int]) -> [[[Int]]] {
        graph.getLayers().map { layer in
            layer.getNodes().map { node in
                // Label, transfer's FIXED_ORDER stamping (property-state
                // divergences must show up, not just geometry), port order.
                let pc = node.getProperty("org.eclipse.elk.portConstraints") as? PortConstraints ?? .UNDEFINED
                return [labels[ObjectIdentifier(node)] ?? -1, pc.isOrderFixed() ? 1 : 0]
                    + node.getPorts().map(\.id)
            }
        }
    }

    /// Runs the OBJECT engine on one graph and the FLAT engine on an
    /// identically-built twin, comparing traces and final graph states.
    private func assertDifferentialParity(_ build: (TestGraphCreator) -> Void, seed: Int,
                                          file: StaticString = #filePath, line: UInt = #line) {
        // Object side: the real driver, pinned to the OBJECT path (the
        // dispatch would otherwise route these fixtures to the flat engine,
        // making this differential vacuously flat-vs-flat).
        let objectCreator = TestGraphCreator()
        build(objectCreator)
        let objectGraph = objectCreator.getGraph()
        objectGraph.setProperty(InternalProperties.RANDOM, Random(seed: seed))
        let objectLabels = labelMap(objectGraph)

        let savedDispatch = LayerSweepCrossingMinimizer.flatEngineEnabled
        LayerSweepCrossingMinimizer.flatEngineEnabled = false
        defer { LayerSweepCrossingMinimizer.flatEngineEnabled = savedDispatch }

        let objectTrace = SweepTrace()
        LayerSweepCrossingMinimizer.trace = objectTrace
        LayerSweepCrossingMinimizer(.BARYCENTER).process(objectGraph, BasicProgressMonitor())

        // Flat side: mirror the driver prelude (nextLong → randomSeed, holder
        // construction consumes the distributor draw), then the flat driver.
        let flatCreator = TestGraphCreator()
        build(flatCreator)
        let flatGraph = flatCreator.getGraph()
        let flatRandom = Random(seed: seed)
        flatGraph.setProperty(InternalProperties.RANDOM, flatRandom)
        let flatLabels = labelMap(flatGraph)

        let flatTrace = SweepTrace()
        LayerSweepCrossingMinimizer.trace = flatTrace
        let randomSeed = Int(flatRandom.nextLong())
        let holder = GraphInfoHolder(flatGraph, .BARYCENTER, [], .BARYCENTER)
        var engine = SweepEngine(graph: SweepGraph(nodeOrder: holder.currentNodeOrder()),
                                 random: flatRandom)
        engine.useNodeRelativeRanks = holder.portDistributor() is NodeRelativePortDistributor
        let strategy = flatGraph.getProperty("org.eclipse.elk.layered.considerModelOrder.strategy")
            as? OrderingStrategy ?? .NONE
        engine.compareDifferentRandomizedLayouts(holder: holder, randomSeed: randomSeed,
                                                 modelOrderStrategyActive: strategy != .NONE)
        engine.transferBestOrders(to: flatGraph)
        LayerSweepCrossingMinimizer.trace = nil

        // Decision-stream parity.
        if let divergence = SweepTrace.firstDivergence(objectTrace, flatTrace) {
            XCTFail("""
            seed \(seed): traces diverge at event \(divergence):
              object: \(objectTrace.events[divergence])
              flat:   \(flatTrace.events[divergence])
            """, file: file, line: line)
            return
        }
        XCTAssertEqual(objectTrace.events.count, flatTrace.events.count,
                       "seed \(seed): one trace is a strict prefix of the other",
                       file: file, line: line)

        // Final-graph parity (transfer included).
        XCTAssertEqual(finalState(objectGraph, objectLabels), finalState(flatGraph, flatLabels),
                       "seed \(seed): transferred graphs differ", file: file, line: line)
    }

    func testThreeLayerGraph() {
        for seed in [1, 2, 3, 4096, 4097] {
            assertDifferentialParity({ c in _ = c.getMoreComplexThreeLayerGraph() }, seed: seed)
        }
    }

    func testInLayerEdges() {
        for seed in [1, 2, 4096] {
            assertDifferentialParity({ c in _ = c.getInLayerEdgesGraph() }, seed: seed)
        }
    }

    func testSelfLoops() {
        for seed in [1, 4096] {
            assertDifferentialParity({ c in _ = c.getCrossWithManySelfLoopsGraph() }, seed: seed)
        }
    }

    func testNorthSouthDummies() {
        for seed in [1, 2, 4096, 4097] {
            assertDifferentialParity({ creator in
                let graph = creator.getGraph()
                let leftLayer = creator.makeLayer(graph)
                let rightLayer = creator.makeLayer(graph)
                let left = creator.addNodeToLayer(leftLayer)
                let owner = creator.addNodeToLayer(rightLayer)
                let dummy = creator.addNodeToLayer(rightLayer)
                creator.addNorthSouthEdge(.NORTH, owner, dummy, left, false)
            }, seed: seed)
        }
    }

    func testFixedPortOrder() {
        for seed in [1, 4096] {
            assertDifferentialParity({ c in _ = c.getFixedPortOrderGraph() }, seed: seed)
        }
    }

    func testCrossFormedGraph() {
        for seed in [1, 2, 3, 4096] {
            assertDifferentialParity({ c in _ = c.getCrossFormedGraph() }, seed: seed)
        }
    }

    /// Hyperedges (a port with >1 edges) route counting to the object
    /// counters on both sides (flat falls back wholesale — address-dependent
    /// tie-breaks, contract §2); the differential proves the fallback wiring.
    func testHyperedgesFallBackToObjectCounting() {
        for seed in [1, 2, 4096] {
            assertDifferentialParity({ c in _ = c.getMultipleEdgesBetweenSameNodesGraph() }, seed: seed)
        }
    }

    /// Zero initial crossings + active strategy: the firstTry early-out
    /// returns before any sweep; the object driver's best sweep is nil so the
    /// graph must stay COMPLETELY untouched (no FIXED_ORDER stamping, no id
    /// rewrite). Regression for the flat transfer falling back to the current
    /// order and stamping anyway.
    func testZeroCrossingsFirstTryLeavesGraphUntouched() {
        for seed in [1, 4096] {
            assertDifferentialParity({ creator in
                let graph = creator.getGraph()
                let left = creator.addNodeToLayer(creator.makeLayer(graph))
                let right = creator.addNodeToLayer(creator.makeLayer(graph))
                creator.eastWestEdgeFromTo(left, right)
                graph.setProperty(
                    "org.eclipse.elk.layered.considerModelOrder.strategy",
                    OrderingStrategy.NODES_AND_EDGES
                )
            }, seed: seed)
        }
    }

    /// The Mermaid pipeline sets `considerModelOrder.strategy = NODES_AND_EDGES`
    /// (influences 0), which activates the firstTry/secondTry rotation: try 1
    /// keeps the initial order sweeping forward, try 2 backward, later tries
    /// randomize. This fixture pins that rotation.
    func testModelOrderStrategyFlagRotation() {
        for seed in [1, 2, 3, 4096, 4097] {
            assertDifferentialParity({ creator in
                _ = creator.getMoreComplexThreeLayerGraph()
                creator.getGraph().setProperty(
                    "org.eclipse.elk.layered.considerModelOrder.strategy",
                    OrderingStrategy.NODES_AND_EDGES
                )
            }, seed: seed)
        }
    }
}
