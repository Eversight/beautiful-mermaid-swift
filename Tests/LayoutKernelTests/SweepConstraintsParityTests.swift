import XCTest
@testable import LayoutKernel

/// Parity between `SweepEngine.processConstraints` (S2' step 3) and the
/// object `ForsterConstraintResolver`: same barycenter states in, identical
/// layer permutation and identical post-resolution barycenter bits out.
/// Randomized barycenters across many seeds drive the resolver through its
/// merge / splice-insert / append paths.
final class SweepConstraintsParityTests: XCTestCase {

    private struct Rig {
        let holder: GraphInfoHolder
        let heuristic: BarycenterHeuristic
        var engine: SweepEngine
        let flat: SweepGraph

        func layerIds(_ l: Int) -> [Int32] {
            holder.currentNodeOrder()[l].map { flat.layerStart[l] + Int32($0.id) }
        }

        func asFlat(_ nodes: [LNode]) -> [Int32] {
            nodes.map { flat.layerStart[$0.getLayer()!.id] + Int32($0.id) }
        }
    }

    private func makeRig(_ graph: LGraph, seed: Int) -> Rig {
        graph.setProperty(InternalProperties.RANDOM, Random(seed: seed))
        let holder = GraphInfoHolder(graph, .BARYCENTER, [], .BARYCENTER)
        let heuristic = holder.crossMinimizer() as! BarycenterHeuristic
        let flat = SweepGraph(nodeOrder: holder.currentNodeOrder())
        let flatRandom = Random(seed: seed)
        _ = flatRandom.nextBoolean()
        return Rig(holder: holder, heuristic: heuristic,
                   engine: SweepEngine(graph: flat, random: flatRandom), flat: flat)
    }

    /// Randomize + sort (step-2-proven lockstep) then resolve on both sides;
    /// assert permutation and per-node barycenter bits. Returns true when
    /// resolution actually changed the order (i.e. merges fired) so callers
    /// can prove their seeds exercised the merge machinery.
    @discardableResult
    private func assertResolutionParity(_ makeGraph: (TestGraphCreator) -> Void,
                                        layerIndex: Int, seed: Int,
                                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let creator = TestGraphCreator()
        makeGraph(creator)
        var rig = makeRig(creator.getGraph(), seed: seed)

        var objectLayer = rig.holder.currentNodeOrder()[layerIndex]
        var flatLayer = rig.layerIds(layerIndex)

        rig.heuristic.randomizeBarycenters(objectLayer)
        rig.engine.randomizeBarycenters(flatLayer)
        rig.heuristic.sortByBarycenter(&objectLayer)
        rig.engine.sortByBarycenter(&flatLayer)
        XCTAssertEqual(flatLayer, rig.asFlat(objectLayer), "pre-resolution sort diverged",
                       file: file, line: line)
        let preResolution = flatLayer

        rig.heuristic.constraintResolver!.processConstraints(&objectLayer)
        rig.engine.processConstraints(&flatLayer)

        XCTAssertEqual(flatLayer, rig.asFlat(objectLayer),
                       "seed \(seed): resolved permutations diverge", file: file, line: line)
        for node in objectLayer {
            let flatId = Int(rig.flat.layerStart[node.getLayer()!.id]) + node.id
            let objectBary = rig.heuristic.stateOf(node).barycenter
            XCTAssertEqual(rig.engine.hasBarycenter[flatId], objectBary != nil,
                           "seed \(seed): hasBarycenter diverges on \(flatId)", file: file, line: line)
            if let objectBary {
                XCTAssertEqual(rig.engine.barycenter[flatId].bitPattern, objectBary.bitPattern,
                               "seed \(seed): barycenter bits diverge on \(flatId)", file: file, line: line)
            }
        }
        return flatLayer != preResolution
    }

    /// No constraints anywhere: resolution must be an order-preserving no-op.
    func testNoConstraintsIsIdentity() {
        for seed in 0..<4 {
            assertResolutionParity({ creator in
                _ = creator.getMoreComplexThreeLayerGraph()
            }, layerIndex: 1, seed: seed)
        }
    }

    /// Successor constraints between north-south DUMMIES and their normal
    /// owner. Dummies stay out of the consecutive-normal chain, so a dummy
    /// randomly sorted onto the wrong side of its owner genuinely violates
    /// and merges. (Constraints between NORMAL nodes cannot merge at all:
    /// the consecutive-normal chain plus any backward constraint forms a
    /// cycle, the topological scan finds no zero-in-degree seed, and
    /// `findViolatedConstraint` returns nil — verified against the object
    /// resolver, which the flat engine mirrors.)
    func testDummyConstraintsMergeAcrossSeeds() {
        var anyMerged = false
        for seed in 0..<16 {
            let changed = assertResolutionParity({ creator in
                let layer = creator.makeLayer(creator.getGraph())
                let nodes = creator.addNodesToLayer(4, layer)
                // nodes[0] is normal; d1/d2 are its north-side dummies which
                // must precede it (as NorthSouthPortPreprocessor arranges).
                creator.setAsNorthSouthNode(nodes[1])
                creator.setAsNorthSouthNode(nodes[2])
                creator.setAsNorthSouthNode(nodes[3])
                creator.setInLayerOrderConstraint(nodes[1], nodes[0])
                creator.setInLayerOrderConstraint(nodes[2], nodes[0])
                // …and a south-side dummy that must follow it.
                creator.setInLayerOrderConstraint(nodes[0], nodes[3])
            }, layerIndex: 0, seed: seed)
            anyMerged = anyMerged || changed
        }
        XCTAssertTrue(anyMerged, "no seed exercised the merge path — fixture too weak to prove parity")
    }

    /// A dummy chained through two constraints (before-owner and after
    /// another dummy) exercises cascaded merges: a merged group re-violates
    /// against its remaining neighbors.
    func testChainedConstraintsCascade() {
        var anyMerged = false
        for seed in 0..<16 {
            let changed = assertResolutionParity({ creator in
                let layer = creator.makeLayer(creator.getGraph())
                let nodes = creator.addNodesToLayer(5, layer)
                creator.setAsNorthSouthNode(nodes[1])
                creator.setAsNorthSouthNode(nodes[2])
                creator.setAsNorthSouthNode(nodes[3])
                creator.setInLayerOrderConstraint(nodes[1], nodes[2])
                creator.setInLayerOrderConstraint(nodes[2], nodes[3])
                creator.setInLayerOrderConstraint(nodes[3], nodes[0])
            }, layerIndex: 0, seed: seed)
            anyMerged = anyMerged || changed
        }
        XCTAssertTrue(anyMerged, "no seed exercised the merge path — fixture too weak to prove parity")
    }

    /// Layout units chain constraints between consecutive NORMAL nodes'
    /// units (north-south dummies travel with their owner); interleaved
    /// random orders violate the unit×unit constraints and merge.
    func testLayoutUnitChaining() {
        var anyMerged = false
        for seed in 0..<16 {
            let changed = assertResolutionParity({ creator in
                let layer = creator.makeLayer(creator.getGraph())
                let nodes = creator.addNodesToLayer(6, layer)
                // n0 and n3 are normal owners; n1/n2 are n0's north-south
                // dummies, n4 is n3's.
                creator.setAsNorthSouthNode(nodes[1])
                creator.setAsNorthSouthNode(nodes[2])
                creator.setAsNorthSouthNode(nodes[4])
                nodes[1].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodes[0] as Any)
                nodes[2].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodes[0] as Any)
                nodes[4].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodes[3] as Any)
                nodes[0].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodes[0] as Any)
                nodes[3].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodes[3] as Any)
            }, layerIndex: 0, seed: seed)
            anyMerged = anyMerged || changed
        }
        XCTAssertTrue(anyMerged, "no seed exercised the merge path — fixture too weak to prove parity")
    }
}
