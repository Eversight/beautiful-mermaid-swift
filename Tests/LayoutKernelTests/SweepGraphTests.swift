import XCTest
@testable import LayoutKernel

/// Invariants of the flat sweep topology (docs/SweepEngineContract.md §3):
/// every array must mirror the object graph exactly, because the flat engine
/// treats `SweepGraph` as the single source of truth during sweeps.
final class SweepGraphTests: XCTestCase {

    /// Runs the init traversal (dense-id assignment) and builds the flat graph.
    private func build(_ graph: LGraph) -> (SweepGraph, GraphInfoHolder) {
        let holder = GraphInfoHolder(graph, .BARYCENTER, [], .BARYCENTER)
        let flat = SweepGraph(nodeOrder: holder.currentNodeOrder())
        return (flat, holder)
    }

    private func assertMirrorsObjectGraph(_ flat: SweepGraph, _ holder: GraphInfoHolder,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let order = holder.currentNodeOrder()

        // Layer structure and id round-trips.
        XCTAssertEqual(flat.layerCount, order.count, file: file, line: line)
        XCTAssertEqual(Int(flat.layerStart.last ?? -1), flat.nodeCount, file: file, line: line)
        var flatId = 0
        for (l, layer) in order.enumerated() {
            XCTAssertEqual(Int(flat.layerStart[l + 1] - flat.layerStart[l]), layer.count, file: file, line: line)
            for node in layer {
                XCTAssertTrue(flat.objectNodes[flatId] === node, file: file, line: line)
                XCTAssertEqual(Int(flat.nodeLayer[flatId]), l, file: file, line: line)

                // Ports contiguous, in getPorts() order, ids matching.
                let ports = node.getPorts()
                let range = Int(flat.nodePortStart[flatId])..<Int(flat.nodePortStart[flatId + 1])
                XCTAssertEqual(range.count, ports.count, file: file, line: line)
                for (offset, port) in ports.enumerated() {
                    let pid = range.lowerBound + offset
                    XCTAssertEqual(port.id, pid, file: file, line: line)
                    XCTAssertTrue(flat.objectPorts[pid] === port, file: file, line: line)
                    XCTAssertEqual(Int(flat.portNode[pid]), flatId, file: file, line: line)
                    XCTAssertEqual(flat.portSide[pid], SweepGraph.sideOrdinal(port.getSide()), file: file, line: line)
                    XCTAssertEqual(Int(flat.portDegree[pid]), port.getDegree(), file: file, line: line)

                    // Adjacency row == object walk (incoming sources then
                    // outgoing targets, nil endpoints skipped, self-loops kept).
                    let expectedIncoming = port.getIncomingEdges().compactMap { $0.getSource()?.id }
                    let expectedOutgoing = port.getOutgoingEdges().compactMap { $0.getTarget()?.id }
                    let row = (Int(flat.adjStart[pid])..<Int(flat.adjStart[pid + 1]))
                        .map { Int(flat.adjFarPort[$0]) }
                    XCTAssertEqual(Int(flat.adjIncomingCount[pid]), expectedIncoming.count, file: file, line: line)
                    XCTAssertEqual(row, expectedIncoming + expectedOutgoing, file: file, line: line)
                }

                // Typed slots vs direct property reads.
                let pc = node.getProperty("org.eclipse.elk.portConstraints") as? PortConstraints ?? .UNDEFINED
                XCTAssertEqual(flat.portConstraintsFixed[flatId], pc.isOrderFixed(), file: file, line: line)
                XCTAssertEqual(flat.isNormalNode[flatId], node.getType() == .NORMAL, file: file, line: line)
                XCTAssertEqual(flat.isExternalPortDummy[flatId], node.getType() == .EXTERNAL_PORT, file: file, line: line)

                flatId += 1
            }
        }
        XCTAssertEqual(flatId, flat.nodeCount, file: file, line: line)
    }

    func testMirrorsThreeLayerGraph() {
        let creator = TestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        let (flat, holder) = build(creator.getGraph())
        assertMirrorsObjectGraph(flat, holder)
        XCTAssertGreaterThan(flat.portCount, 0)
    }

    func testSelfLoopsStayInAdjacency() {
        let creator = TestGraphCreator()
        _ = creator.getCrossWithManySelfLoopsGraph()
        let (flat, holder) = build(creator.getGraph())
        assertMirrorsObjectGraph(flat, holder)

        // The port distributor's in-layer detection fires on self-loops, so
        // at least one adjacency entry must point back at the same node.
        var hasSelfLoopEntry = false
        for pid in 0..<flat.portCount {
            for i in Int(flat.adjStart[pid])..<Int(flat.adjStart[pid + 1])
            where flat.portNode[Int(flat.adjFarPort[i])] == flat.portNode[pid] {
                hasSelfLoopEntry = true
            }
        }
        XCTAssertTrue(hasSelfLoopEntry, "self-loop graph must keep self-loop adjacency entries")
    }

    func testInLayerEdgesGraph() {
        let creator = TestGraphCreator()
        _ = creator.getInLayerEdgesGraph()
        let (flat, holder) = build(creator.getGraph())
        assertMirrorsObjectGraph(flat, holder)

        // In-layer edges: some adjacency entry's far node is in the same layer.
        var hasInLayer = false
        for pid in 0..<flat.portCount {
            let selfLayer = flat.nodeLayer[Int(flat.portNode[pid])]
            for i in Int(flat.adjStart[pid])..<Int(flat.adjStart[pid + 1])
            where flat.nodeLayer[Int(flat.portNode[Int(flat.adjFarPort[i])])] == selfLayer {
                hasInLayer = true
            }
        }
        XCTAssertTrue(hasInLayer)
    }

    func testFixedPortOrderSlot() {
        let creator = TestGraphCreator()
        _ = creator.getFixedPortOrderGraph()
        let (flat, holder) = build(creator.getGraph())
        assertMirrorsObjectGraph(flat, holder)
        XCTAssertTrue(flat.portConstraintsFixed.contains(true),
                      "fixed-port-order graph must surface at least one fixed node")
    }
}
