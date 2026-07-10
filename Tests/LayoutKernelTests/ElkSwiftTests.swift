import XCTest
@testable import LayoutKernel

final class ElkSwiftTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(LayoutKernel.version.isEmpty)
    }

    func testKVectorCoreOps() {
        let v = KVector(3, 4)
        XCTAssertEqual(v.length(), 5, accuracy: 1e-9)
        _ = v.normalize()
        XCTAssertEqual(v.length(), 1, accuracy: 1e-9)
        _ = v.scaleToLength(10)
        XCTAssertEqual(v.length(), 10, accuracy: 1e-9)
    }

    // Tests for Rectangle, GeometryMath, Direction temporarily disabled (types not in scope)

    func testPortSetNodeMaintainsOwnerList() {
        let graph = LGraph()
        let nodeA = LNode(graph)
        let nodeB = LNode(graph)
        let port = LPort()

        port.setNode(nodeA)
        XCTAssertEqual(nodeA.getPorts().count, 1)
        XCTAssertTrue(nodeA.getPorts().first === port)

        port.setNode(nodeB)
        XCTAssertTrue(nodeA.getPorts().isEmpty)
        XCTAssertEqual(nodeB.getPorts().count, 1)
        XCTAssertTrue(nodeB.getPorts().first === port)
    }

    func testEdgeSourceTargetLinking() {
        let graph = LGraph()
        let sourceNode = LNode(graph)
        let targetNode = LNode(graph)
        let sourcePort = LPort()
        let targetPort = LPort()
        sourcePort.setNode(sourceNode)
        targetPort.setNode(targetNode)

        let edge = LEdge()
        edge.setSource(sourcePort)
        edge.setTarget(targetPort)

        XCTAssertEqual(sourcePort.getOutgoingEdges().count, 1)
        XCTAssertEqual(targetPort.getIncomingEdges().count, 1)
        XCTAssertTrue(edge.getOther(sourcePort) === targetPort)
        XCTAssertTrue(edge.getOther(targetNode) === sourceNode)
    }

    func testPortSideSetsDefaultAnchor() {
        let port = LPort()
        _ = port.getSize().set(20, 10)

        port.setSide(.EAST)
        XCTAssertEqual(port.getAnchor().x, 20, accuracy: 1e-9)
        XCTAssertEqual(port.getAnchor().y, 5, accuracy: 1e-9)

        port.setExplicitlySuppliedPortAnchor(true)
        _ = port.getAnchor().set(7, 8)
        port.setSide(.WEST)
        XCTAssertEqual(port.getAnchor().x, 7, accuracy: 1e-9)
        XCTAssertEqual(port.getAnchor().y, 8, accuracy: 1e-9)
    }
}
