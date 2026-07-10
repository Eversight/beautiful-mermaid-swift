import XCTest
@testable import LayoutKernel

/// Parity between `SweepEngine`'s flat port distribution (S2' step 4) and
/// `AbstractBarycenterPortDistributor`: after the same sequence of
/// `distributePortsWhileSweeping` calls, port ranks and barycenters must
/// match to the Float bit, and every node's port order must be identical.
final class SweepPortDistributionParityTests: XCTestCase {

    private struct Rig {
        let holder: GraphInfoHolder
        let distributor: AbstractBarycenterPortDistributor
        var engine: SweepEngine
        let flat: SweepGraph
    }

    private func makeRig(_ graph: LGraph, seed: Int) -> Rig {
        graph.setProperty(InternalProperties.RANDOM, Random(seed: seed))
        let holder = GraphInfoHolder(graph, .BARYCENTER, [], .BARYCENTER)
        let distributor = holder.portDistributor() as! AbstractBarycenterPortDistributor

        let flat = SweepGraph(nodeOrder: holder.currentNodeOrder())
        let flatRandom = Random(seed: seed)
        var engine = SweepEngine(graph: flat, random: flatRandom)
        // Mirror the object side's distributor choice with the same draw.
        engine.useNodeRelativeRanks = flatRandom.nextBoolean()
        XCTAssertEqual(engine.useNodeRelativeRanks, distributor is NodeRelativePortDistributor,
                       "flat engine mirrored a different distributor than the object side chose")
        return Rig(holder: holder, distributor: distributor, engine: engine, flat: flat)
    }

    private func assertPortStateParity(_ rig: Rig, file: StaticString = #filePath, line: UInt = #line) {
        // Ranks and barycenters, Float bit patterns. The object arrays can be
        // shorter (they grow lazily); missing entries mean untouched zeros.
        let objectRanks = rig.distributor.getPortRanks()
        for pid in 0..<rig.flat.portCount {
            let objectRank: Float = pid < objectRanks.count ? objectRanks[pid] : 0
            XCTAssertEqual(rig.engine.portRank[pid].bitPattern, objectRank.bitPattern,
                           "portRank bits diverge on port \(pid)", file: file, line: line)
            let objectBary = rig.distributor.barycenterOf(rig.flat.objectPorts[pid])
            XCTAssertEqual(rig.engine.portBarycenter[pid].bitPattern, objectBary.bitPattern,
                           "portBarycenter bits diverge on port \(pid)", file: file, line: line)
        }
        // Port order per node.
        for (n, node) in rig.flat.objectNodes.enumerated() {
            let objectOrder = node.getPorts().map { Int32($0.id) }
            let range = Int(rig.flat.nodePortStart[n])..<Int(rig.flat.nodePortStart[n + 1])
            XCTAssertEqual(Array(rig.engine.portOrder[range]), objectOrder,
                           "port order diverges on node \(n)", file: file, line: line)
        }
    }

    /// Sweeps forward then backward over every layer, distributing at each
    /// step exactly like the driver does, on both sides.
    private func assertSweepParity(_ makeGraph: (TestGraphCreator) -> Void, seed: Int,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let creator = TestGraphCreator()
        makeGraph(creator)
        var rig = makeRig(creator.getGraph(), seed: seed)
        let layerCount = rig.holder.currentNodeOrder().count

        for index in 0..<layerCount {
            _ = rig.distributor.distributePortsWhileSweeping(rig.holder.currentNodeOrder(), index, true)
            rig.engine.distributePortsWhileSweeping(index, forward: true)
        }
        assertPortStateParity(rig, file: file, line: line)

        for index in stride(from: layerCount - 1, through: 0, by: -1) {
            _ = rig.distributor.distributePortsWhileSweeping(rig.holder.currentNodeOrder(), index, false)
            rig.engine.distributePortsWhileSweeping(index, forward: false)
        }
        assertPortStateParity(rig, file: file, line: line)
    }

    func testThreeLayerGraphBothDistributors() {
        // The LCG's first boolean is decided by high seed bits: seeds
        // 0..<4096 all pick NodeRelative, 4096.. pick LayerTotal (probed
        // empirically). Use both bands so both calculators are exercised.
        var sawNodeRelative = false, sawLayerTotal = false
        for seed in [0, 1, 2, 4096, 4097, 4098] {
            let creator = TestGraphCreator()
            _ = creator.getMoreComplexThreeLayerGraph()
            let rig = makeRig(creator.getGraph(), seed: seed)
            if rig.engine.useNodeRelativeRanks { sawNodeRelative = true } else { sawLayerTotal = true }

            assertSweepParity({ c in _ = c.getMoreComplexThreeLayerGraph() }, seed: seed)
        }
        XCTAssertTrue(sawNodeRelative && sawLayerTotal,
                      "seeds must exercise both rank calculators")
    }

    func testInLayerEdges() {
        for seed in 0..<4 {
            assertSweepParity({ c in _ = c.getInLayerEdgesGraph() }, seed: seed)
        }
    }

    func testSelfLoops() {
        for seed in 0..<4 {
            assertSweepParity({ c in _ = c.getCrossWithManySelfLoopsGraph() }, seed: seed)
        }
    }

    func testFixedPortOrderStaysUntouched() {
        for seed in 0..<4 {
            assertSweepParity({ c in _ = c.getFixedPortOrderGraph() }, seed: seed)
        }
    }

    func testNorthSouthDummies() {
        for seed in 0..<6 {
            assertSweepParity({ creator in
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
}
