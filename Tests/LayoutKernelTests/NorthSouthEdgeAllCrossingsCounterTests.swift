// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.counting.NorthSouthEdgeAllCrossingsCounterTest

import XCTest
@testable import LayoutKernel

final class NorthSouthEdgeAllCrossingsCounterTests: XCTestCase {

    // MARK: - Helpers

    private func countNSCrossingsInLayer(_ creator: NorthSouthEdgeTestGraphCreator, layerIndex: Int) -> Int {
        creator.setUpIds()
        let graph = creator.getGraph()
        var numPorts = 0
        for layer in graph.getLayers() {
            for node in layer.getNodes() {
                numPorts += node.getPorts().count
            }
        }
        let counter = CrossingsCounter([Int](repeating: 0, count: numPorts))
        return counter.countNorthSouthPortCrossingsInLayer(graph.toNodeArray()[layerIndex])
    }

    // MARK: - Tests

    func testNorthernNorthSouthNodeSingleCrossing() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthUpwardCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 1)
    }

    func testNorthernNorthSouthNodeMultipleCrossings() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthUpwardMultipleCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 3)
    }

    func testSouthernTwoEdgeEastCrossing() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthDownwardCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 1)
    }

    func testSouthernNorthSouthMultipleNodeCrossing() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthDownwardMultipleCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 3)
    }

    func testSouthernTwoWesternEdges() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthSouthernTwoWesternEdges()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 1)
    }

    func testSouthernThreeWesternEdges() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthSouthernThreeWesternEdges()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 3)
    }

    func testNorthSouthEdgesComeFromBothSidesDontCross() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getSouthernNorthSouthGraphEdgesFromEastAndWestNoCrossings()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 0)
    }

    func testSouthernNorthSouthEdgesBothToEastDontCross() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getSouthernNorthSouthEdgesBothToEast()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 0)
    }

    func testNorthSouthEdgesComeFromBothSidesDoCross() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthEdgesFromEastAndWestAndCross()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 1)
    }

    func testNorthernBothEdgesWestern() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthNorthernWesternEdges()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 0)
    }

    func testNorthernEasternPortToWestWesternPortToEast() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthNorthernEasternPortToWestWesternPortToEast()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 1)
    }

    func testAllSidesMultipleCrossings() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getNorthSouthAllSidesMultipleCrossings()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 4)
    }

    func testOneEdgeDummyIsCrossedByOneSouthernNorthSouthPortEdge() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getSouthernNorthSouthDummyEdgeCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 1)
    }

    func testOneEdgeDummyIsCrossedByTwoSouthernNorthSouthPortEdges() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getSouthernNorthSouthDummyEdgeTwoCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 2)
    }

    func testSouthernTwoDummyEdgeAndTwoNorthSouthShouldCrossFourTimes() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getSouthernTwoDummyEdgeAndNorthSouthCrossingGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 4)
    }

    func testNormalNodesNorthSouthEdgesHaveCrossingsToLongEdgeDummyOnBothSides() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getMultipleNorthSouthAndLongEdgeDummiesOnBothSides()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 4)
    }

    func testIgnoresUnconnectedPortsForNormalNodeAndLongEdgeDummies() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getLongEdgeDummyAndNormalNodeWithUnusedPortsOnSouthernSide()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 0)
    }

    func testNoNorthSouthNode() {
        let creator = NorthSouthEdgeTestGraphCreator()
        _ = creator.getCrossFormedGraph()
        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 0), 0)
    }

    func testMoreThanOneEdgeIntoNSNode_countsTheseToo() {
        let creator = NorthSouthEdgeTestGraphCreator()
        let leftNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let middleNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))

        creator.setFixedOrderConstraint(middleNodes[2])

        // ports are added in clockwise fashion
        creator.addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[1], rightNodes[0], false)
        creator.addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], leftNode, true)
        // second edge on middle node
        let middleNodePort = middleNodes[1].getPorts()[0]
        creator.eastWestEdgeFromTo(middleNodePort, rightNodes[1])

        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 2)
    }

    func testTheOneThatFailedWithTheOldCounting() {
        let creator = NorthSouthEdgeTestGraphCreator()
        let leftNodes = creator.addNodesToLayer(4, creator.makeLayer(creator.getGraph()))
        let middleNodes = creator.addNodesToLayer(5, creator.makeLayer(creator.getGraph()))

        creator.setFixedOrderConstraint(middleNodes[4])

        for i in stride(from: 3, through: 0, by: -1) {
            creator.addNorthSouthEdge(.NORTH, middleNodes[4], middleNodes[i], leftNodes[i], false)
        }

        XCTAssertEqual(countNSCrossingsInLayer(creator, layerIndex: 1), 0)
    }
}
