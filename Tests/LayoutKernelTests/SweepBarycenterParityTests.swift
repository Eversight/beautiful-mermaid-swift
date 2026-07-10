import XCTest
@testable import LayoutKernel

/// Bit-level parity between `SweepEngine`'s flat barycenter (S2' step 2) and
/// the object `BarycenterHeuristic`: same seeded Random on both sides, same
/// port ranks, then every barycenter must match to the bit and every sorted
/// layer must be the same permutation.
final class SweepBarycenterParityTests: XCTestCase {

    private struct Rig {
        let holder: GraphInfoHolder
        let heuristic: BarycenterHeuristic
        let distributor: AbstractBarycenterPortDistributor
        var engine: SweepEngine
        let flat: SweepGraph

        /// Object layer (current order) and its flat twin, as flat ids.
        func layerIds(_ l: Int) -> [Int32] {
            holder.currentNodeOrder()[l].map { node in
                flat.layerStart[l] + Int32(node.id)
            }
        }
    }

    /// Both sides consume one `nextBoolean()` before any sweep draw: the
    /// object side inside `GraphInfoHolder.init` (distributor choice), the
    /// flat side mirrored explicitly.
    private func makeRig(_ graph: LGraph, seed: Int = 7) -> Rig {
        graph.setProperty(InternalProperties.RANDOM, Random(seed: seed))
        let holder = GraphInfoHolder(graph, .BARYCENTER, [], .BARYCENTER)
        let heuristic = holder.crossMinimizer() as! BarycenterHeuristic
        let distributor = holder.portDistributor() as! AbstractBarycenterPortDistributor

        let flat = SweepGraph(nodeOrder: holder.currentNodeOrder())
        let flatRandom = Random(seed: seed)
        _ = flatRandom.nextBoolean()
        let engine = SweepEngine(graph: flat, random: flatRandom)
        return Rig(holder: holder, heuristic: heuristic, distributor: distributor,
                   engine: engine, flat: flat)
    }

    private func assertBarycentersMatch(_ rig: Rig, _ layer: [LNode],
                                        file: StaticString = #filePath, line: UInt = #line) {
        for node in layer {
            let flatId = Int(rig.flat.layerStart[node.getLayer()!.id]) + node.id
            let objectState = rig.heuristic.stateOf(node)
            XCTAssertEqual(rig.engine.hasBarycenter[flatId], objectState.barycenter != nil,
                           "hasBarycenter mismatch on node \(flatId)", file: file, line: line)
            if let objectValue = objectState.barycenter {
                XCTAssertEqual(rig.engine.barycenter[flatId].bitPattern, objectValue.bitPattern,
                               "barycenter bits diverge on node \(flatId)", file: file, line: line)
            }
            XCTAssertEqual(Int(rig.engine.degree[flatId]), objectState.degree, file: file, line: line)
            XCTAssertEqual(rig.engine.summedWeight[flatId].bitPattern, objectState.summedWeight.bitPattern,
                           "summedWeight bits diverge on node \(flatId)", file: file, line: line)
        }
    }

    func testRandomizeAndSortParity() {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        var rig = makeRig(creator.getGraph())

        var objectLayer = rig.holder.currentNodeOrder()[0]
        var flatLayer = rig.layerIds(0)

        rig.heuristic.randomizeBarycenters(objectLayer)
        rig.engine.randomizeBarycenters(flatLayer)
        assertBarycentersMatch(rig, objectLayer)

        rig.heuristic.sortByBarycenter(&objectLayer)
        rig.engine.sortByBarycenter(&flatLayer)
        let objectAsFlat = objectLayer.map { rig.flat.layerStart[0] + Int32($0.id) }
        XCTAssertEqual(flatLayer, objectAsFlat, "sorted permutations diverge")
    }

    func testCalculateForwardParity() {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        var rig = makeRig(creator.getGraph())

        // Ranks on the fixed layer feed the free layer's barycenters.
        rig.distributor.calculatePortRanks(rig.holder.currentNodeOrder()[0], .OUTPUT)
        rig.engine.portRank = rig.distributor.getPortRanks()

        var objectLayer = rig.holder.currentNodeOrder()[1]
        var flatLayer = rig.layerIds(1)

        rig.heuristic.calculateBarycenters(objectLayer, true)
        rig.heuristic.fillInUnknownBarycenters(objectLayer, false)
        rig.engine.calculateBarycenters(flatLayer, forward: true)
        rig.engine.fillInUnknownBarycenters(flatLayer, preOrdered: false)
        assertBarycentersMatch(rig, objectLayer)

        rig.heuristic.sortByBarycenter(&objectLayer)
        rig.engine.sortByBarycenter(&flatLayer)
        let objectAsFlat = objectLayer.map { rig.flat.layerStart[1] + Int32($0.id) }
        XCTAssertEqual(flatLayer, objectAsFlat)
    }

    func testCalculateBackwardParity() {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        var rig = makeRig(creator.getGraph(), seed: 42)

        rig.distributor.calculatePortRanks(rig.holder.currentNodeOrder()[2], .INPUT)
        rig.engine.portRank = rig.distributor.getPortRanks()

        var objectLayer = rig.holder.currentNodeOrder()[1]
        var flatLayer = rig.layerIds(1)

        rig.heuristic.calculateBarycenters(objectLayer, false)
        rig.heuristic.fillInUnknownBarycenters(objectLayer, false)
        rig.engine.calculateBarycenters(flatLayer, forward: false)
        rig.engine.fillInUnknownBarycenters(flatLayer, preOrdered: false)
        assertBarycentersMatch(rig, objectLayer)

        rig.heuristic.sortByBarycenter(&objectLayer)
        rig.engine.sortByBarycenter(&flatLayer)
        XCTAssertEqual(flatLayer, objectLayer.map { rig.flat.layerStart[1] + Int32($0.id) })
    }

    /// In-layer edges force the recursive same-layer DFS — the random draws
    /// happen in post-order, so a traversal-order slip would shift the stream.
    func testInLayerRecursionParity() {
        let creator = TestGraphCreator()
        _ = creator.getInLayerEdgesGraph()
        var rig = makeRig(creator.getGraph(), seed: 3)

        rig.distributor.calculatePortRanks(rig.holder.currentNodeOrder()[0], .OUTPUT)
        rig.engine.portRank = rig.distributor.getPortRanks()

        var objectLayer = rig.holder.currentNodeOrder()[1]
        var flatLayer = rig.layerIds(1)

        rig.heuristic.calculateBarycenters(objectLayer, true)
        rig.heuristic.fillInUnknownBarycenters(objectLayer, false)
        rig.engine.calculateBarycenters(flatLayer, forward: true)
        rig.engine.fillInUnknownBarycenters(flatLayer, preOrdered: false)
        assertBarycentersMatch(rig, objectLayer)

        rig.heuristic.sortByBarycenter(&objectLayer)
        rig.engine.sortByBarycenter(&flatLayer)
        XCTAssertEqual(flatLayer, objectLayer.map { rig.flat.layerStart[1] + Int32($0.id) })
    }

    /// The preOrdered fill-in interpolates midpoints and must draw NOTHING —
    /// verified by both sides staying in random lockstep afterwards.
    func testPreOrderedFillInDrawsNothing() {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        var rig = makeRig(creator.getGraph(), seed: 11)

        rig.distributor.calculatePortRanks(rig.holder.currentNodeOrder()[0], .OUTPUT)
        rig.engine.portRank = rig.distributor.getPortRanks()

        let objectLayer = rig.holder.currentNodeOrder()[1]
        let flatLayer = rig.layerIds(1)

        rig.heuristic.calculateBarycenters(objectLayer, true)
        rig.heuristic.fillInUnknownBarycenters(objectLayer, true)
        rig.engine.calculateBarycenters(flatLayer, forward: true)
        rig.engine.fillInUnknownBarycenters(flatLayer, preOrdered: true)
        assertBarycentersMatch(rig, objectLayer)

        // Lockstep proof: the next draw on each side must be identical.
        let objectNext = (rig.heuristic.random?.nextDouble())!
        let flatNext = (rig.engine.random?.nextDouble())!
        XCTAssertEqual(objectNext.bitPattern, flatNext.bitPattern,
                       "random streams desynchronized — something drew unequally")
    }
}
