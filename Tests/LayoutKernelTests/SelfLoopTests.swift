// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of ELK self-loop tests.

import XCTest
@testable import LayoutKernel
final class SelfLoopTests: XCTestCase {

    // MARK: - SelfLoopHolder: needsSelfLoopProcessing

    func testNeedsSelfLoopProcessing_normalNodeWithSelfLoop() {
        let graph = LGraph()
        let node = LNode(graph)
        node.setType(.NORMAL)

        let port1 = LPort()
        port1.setNode(node)
        let port2 = LPort()
        port2.setNode(node)

        let edge = LEdge()
        edge.setSource(port1)
        edge.setTarget(port2)

        XCTAssertTrue(SelfLoopHolder.needsSelfLoopProcessing(node),
            "Normal node with a self-loop edge should need self-loop processing")
    }

    func testNeedsSelfLoopProcessing_normalNodeWithoutSelfLoop() {
        let graph = LGraph()
        let node1 = LNode(graph)
        node1.setType(.NORMAL)
        let node2 = LNode(graph)
        node2.setType(.NORMAL)

        let port1 = LPort()
        port1.setNode(node1)
        let port2 = LPort()
        port2.setNode(node2)

        let edge = LEdge()
        edge.setSource(port1)
        edge.setTarget(port2)

        XCTAssertFalse(SelfLoopHolder.needsSelfLoopProcessing(node1),
            "Normal node without self-loop edges should not need self-loop processing")
    }

    func testNeedsSelfLoopProcessing_nonNormalNode() {
        let graph = LGraph()
        let node = LNode(graph)
        node.setType(.LONG_EDGE)

        let port1 = LPort()
        port1.setNode(node)
        let port2 = LPort()
        port2.setNode(node)

        let edge = LEdge()
        edge.setSource(port1)
        edge.setTarget(port2)

        XCTAssertFalse(SelfLoopHolder.needsSelfLoopProcessing(node),
            "Non-NORMAL node should not need self-loop processing even with self-loop edge")
    }

    // MARK: - SelfLoopHolder: install and basic properties

    func testInstall_createsHolderWithCorrectNode() {
        let graph = LGraph()
        let node = LNode(graph)
        node.setType(.NORMAL)

        let port1 = LPort()
        port1.setNode(node)
        let port2 = LPort()
        port2.setNode(node)

        let edge = LEdge()
        edge.setSource(port1)
        edge.setTarget(port2)

        let holder = SelfLoopHolder.install(node)
        XCTAssertTrue(holder.getLNode() === node,
            "Installed holder should reference the original node")
    }

    func testInstall_detectsSelfLoopEdges() {
        let graph = LGraph()
        let node = LNode(graph)
        node.setType(.NORMAL)

        let port1 = LPort()
        port1.setNode(node)
        let port2 = LPort()
        port2.setNode(node)

        let edge = LEdge()
        edge.setSource(port1)
        edge.setTarget(port2)

        let holder = SelfLoopHolder.install(node)

        // Should have found one hyper-loop containing the self-loop edge
        XCTAssertGreaterThan(holder.getSLHyperLoops().count, 0,
            "Holder should detect at least one self-loop hyper-loop")
        // Should have two self-loop ports
        XCTAssertEqual(holder.getSLPortValues().count, 2,
            "Holder should have two self-loop ports (source and target)")
    }

    // MARK: - PolylineSelfLoopRouter: cutCorners

    func testPolylineSelfLoopRouter_cutCorners_usualCase() {
        // Input: a rectangular self-loop path with 6 points
        // (0,0) -> (100,0) -> (100,100) -> (-100,100) -> (-100,-100) -> (0,-100)
        let input = KVectorChain()
        input.add(KVector(0, 0))
        input.add(KVector(100, 0))
        input.add(KVector(100, 100))
        input.add(KVector(-100, 100))
        input.add(KVector(-100, -100))
        input.add(KVector(0, -100))

        let router = PolylineSelfLoopRouter()
        let result = router.cutCorners(input, 10)

        // 6 input points -> 4 inner corners -> 8 output points (2 per corner)
        XCTAssertEqual(result.size(), 8,
            "cutCorners should produce 2 points per inner corner (4 corners = 8 points)")

        // Verify approximate expected coordinates for each cut corner:
        // Corner (100,0): from (0,0) and (100,100)
        //   offset1 direction: (0,0)-(100,0) = (-100,0) normalized to (-10,0) -> (90,0)
        //   offset2 direction: (100,100)-(100,0) = (0,100) normalized to (0,10) -> (100,10)
        assertPointApprox(result.get(0), expectedX: 90, expectedY: 0, label: "corner1-pre")
        assertPointApprox(result.get(1), expectedX: 100, expectedY: 10, label: "corner1-post")

        // Corner (100,100): from (100,0) and (-100,100)
        assertPointApprox(result.get(2), expectedX: 100, expectedY: 90, label: "corner2-pre")
        assertPointApprox(result.get(3), expectedX: 90, expectedY: 100, label: "corner2-post")

        // Corner (-100,100): from (100,100) and (-100,-100)
        assertPointApprox(result.get(4), expectedX: -90, expectedY: 100, label: "corner3-pre")
        assertPointApprox(result.get(5), expectedX: -100, expectedY: 90, label: "corner3-post")

        // Corner (-100,-100): from (-100,100) and (0,-100)
        assertPointApprox(result.get(6), expectedX: -100, expectedY: -90, label: "corner4-pre")
        assertPointApprox(result.get(7), expectedX: -90, expectedY: -100, label: "corner4-post")
    }

    func testPolylineSelfLoopRouter_cutCorners_smallSegment() {
        // When a segment is shorter than 2*distance, the effective distance is halved
        let input = KVectorChain()
        input.add(KVector(0, 0))
        input.add(KVector(8, 0))   // segment length = 8, so effective distance = min(10, 4) = 4
        input.add(KVector(8, 100))

        let router = PolylineSelfLoopRouter()
        let result = router.cutCorners(input, 10)

        // 3 input points -> 1 inner corner -> 2 output points
        XCTAssertEqual(result.size(), 2,
            "cutCorners with 3 points should produce 2 output points")

        // Effective distance = min(10, 8/2, 100/2) = 4
        assertPointApprox(result.get(0), expectedX: 4, expectedY: 0, label: "small-pre")
        assertPointApprox(result.get(1), expectedX: 8, expectedY: 4, label: "small-post")
    }

    // MARK: - Helpers

    private func assertPointApprox(_ point: KVector, expectedX: Double, expectedY: Double,
                                    accuracy: Double = 1.0, label: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, expectedX, accuracy: accuracy,
            "\(label): x should be ~\(expectedX) but was \(point.x)", file: file, line: line)
        XCTAssertEqual(point.y, expectedY, accuracy: accuracy,
            "\(label): y should be ~\(expectedY) but was \(point.y)", file: file, line: line)
    }
}
