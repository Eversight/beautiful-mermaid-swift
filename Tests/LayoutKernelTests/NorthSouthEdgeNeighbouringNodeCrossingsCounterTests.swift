// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.NorthSouthEdgeNeighbouringNodeCrossingsCounterTest

import XCTest
@testable import LayoutKernel

final class NorthSouthEdgeNeighbouringNodeCrossingsCounterTests: XCTestCase {

    private var creator: NorthSouthEdgeTestGraphCreator!
    private var counter: NorthSouthEdgeNeighbouringNodeCrossingsCounter!
    private var layer: [LNode]!

    override func setUp() {
        super.setUp()
        creator = NorthSouthEdgeTestGraphCreator()
        layer = nil
        LayoutMetaDataService.initElkReflect()
    }

    // MARK: - Helpers

    private func countCrossingsInLayerBetweenNodes(_ layerIndex: Int, _ upperNodeIndex: Int, _ lowerNodeIndex: Int) {
        if layer == nil {
            layer = creator.getGraph().toNodeArray()[layerIndex]
        }
        counter = NorthSouthEdgeNeighbouringNodeCrossingsCounter(layer)
        counter.countCrossings(layer[upperNodeIndex], layer[lowerNodeIndex])
    }

    private func switchNodes(_ upper: Int, _ lower: Int) {
        let upperNode = layer[upper]
        let lowerNode = layer[lower]
        layer[upper] = lowerNode
        layer[lower] = upperNode
    }

    private func switchAndRecount(_ upperNodeIndex: Int, _ lowerNodeIndex: Int) {
        switchNodes(upperNodeIndex, lowerNodeIndex)
        counter.countCrossings(layer[upperNodeIndex], layer[lowerNodeIndex])
    }

    // MARK: - Tests

    func test_noNorthSouthNode() {
        creator.getCrossFormedGraph()
        countCrossingsInLayerBetweenNodes(0, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_southernNorthSouthNodeCrossing() {
        creator.getNorthSouthDownwardCrossingGraph()
        countCrossingsInLayerBetweenNodes(0, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_northernNorthSouthNodeCrossings() {
        creator.getNorthSouthUpwardCrossingGraph()
        countCrossingsInLayerBetweenNodes(0, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_oneNodeIsLongEdgeDummy() {
        creator.getSouthernNorthSouthDummyEdgeCrossingGraph()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        switchNodes(1, 2)
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_oneNodeIsLongEdgeDummyNorthern() {
        creator.getNorthernNorthSouthDummyEdgeCrossingGraph()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        switchNodes(0, 1)
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_withNormalNode() {
        creator.getNorthSouthDownwardCrossingGraph()
        countCrossingsInLayerBetweenNodes(0, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_northSouthEdgesComeFromBothSidesDontCross() {
        creator.getSouthernNorthSouthGraphEdgesFromEastAndWestNoCrossings()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        // Reset for the northern case
        layer = nil
        creator = NorthSouthEdgeTestGraphCreator()
        creator.getNorthernNorthSouthGraphEdgesFromEastAndWestNoCrossings()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_southernNorthSouthEdgesBothToEast() {
        creator.getSouthernNorthSouthEdgesBothToEast()
        countCrossingsInLayerBetweenNodes(0, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_crossingsWithNorthSouthPortsBelongingToDifferentNodesShouldNotBeCounted() {
        creator.getGraphWhereLayoutUnitPreventsSwitch()
        countCrossingsInLayerBetweenNodes(0, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_northSouthEdgesComeFromBothSidesDoCross() {
        creator.getNorthSouthEdgesFromEastAndWestAndCross()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_switchNodesAndRecount() {
        creator.getNorthSouthUpwardCrossingGraph()
        countCrossingsInLayerBetweenNodes(0, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
        switchAndRecount(0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_southPortOnNormalNodeBelowLongEdgeDummy() {
        creator.getSouthPortOnNormalNodeBelowLongEdgeDummy()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
        switchAndRecount(0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_northPortOnNormalNodeAboveLongEdgeDummy() {
        creator.getNorthPortOndNormalNodeAboveLongEdgeDummy()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
        switchAndRecount(1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_southernTwoWesternEdges() {
        creator.getNorthSouthSouthernTwoWesternEdges()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
        switchAndRecount(1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_southernWesternPortToEastAndEasternPortToWest() {
        creator.getNorthSouthSouthernWesternPortToEastAndEasternPortToWest()
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
        switchAndRecount(1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_northernBothEdgesWestern() {
        creator.getNorthSouthNorthernWesternEdges()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
        switchAndRecount(0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_northernEasternPortToWestWesternPortToEast() {
        creator.getNorthSouthNorthernEasternPortToWestWesternPortToEast()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
        switchAndRecount(0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    func test_normalNodesNorthSouthEdgesHaveCrossingsToLongEdgeDummy() {
        creator.getNorthernNorthSouthDummyEdgeCrossingGraph()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        // Reset layer to force re-read
        layer = nil
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        // Southern case
        layer = nil
        creator = NorthSouthEdgeTestGraphCreator()
        creator.getSouthernNorthSouthDummyEdgeCrossingGraph()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)

        layer = nil
        countCrossingsInLayerBetweenNodes(1, 1, 2)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_normalNodesNorthSouthEdgesHaveCrossingsToLongEdgeDummyOnBothSides() {
        creator.getMultipleNorthSouthAndLongEdgeDummiesOnBothSides()
        countCrossingsInLayerBetweenNodes(1, 2, 3)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 2)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 2)
    }

    func test_ignoresUnconnectedPortsForNormalNodeAndLongEdgeDummies() {
        creator.getLongEdgeDummyAndNormalNodeWithUnusedPortsOnSouthernSide()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)

        layer = nil
        creator = NorthSouthEdgeTestGraphCreator()
        creator.getLongEdgeDummyAndNormalNodeWithUnusedPortsOnNorthernSide()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
    }

    func test_oneEdgeWestOneEdgeEastDontCross() {
        creator.getNorthernNorthSouthGraphEdgesFromEastAndWestNoCrossings()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    func test_oneEdgeEastOneEdgeWestDontCross() {
        creator.getNorthernNorthSouthGraphEdgesFromEastAndWestNoCrossingsUpperEdgeEast()
        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 0)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    /// Polyline routing with more than one edge into NS node:
    func test_givenPolylineRoutingWhenMoreThanOneEdgeIntoNSNode_countsTheseToo() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let middleNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))

        creator.setFixedOrderConstraint(middleNodes[2])

        // ports are added in clockwise fashion
        creator.addNorthSouthEdge(PortSide.NORTH, middleNodes[2], middleNodes[1], rightNodes[0], false)
        creator.addNorthSouthEdge(PortSide.NORTH, middleNodes[2], middleNodes[0], leftNode, true)
        // second edge on middle node
        let middleNodePort = middleNodes[1].getPorts()[0]
        creator.eastWestEdgeFromTo(middleNodePort, rightNodes[1])
        creator.getGraph().setProperty(LayeredOptions.EDGE_ROUTING, EdgeRouting.POLYLINE)

        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 2)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    /// Multiple edges in one NS node:
    func test_givenMultipleEdgesInOneNSNodeCountsCrossings() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer())
        let middleLayer = creator.addNodesToLayer(3, creator.makeLayer())
        let rightLayer = creator.addNodesToLayer(2, creator.makeLayer())

        creator.setFixedOrderConstraint(middleLayer[2])

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[1], leftNode, true)

        let normalNodePort = creator.addPortOnSide(rightLayer[1], PortSide.WEST)
        let dummyNodePort = creator.addPortOnSide(middleLayer[1], PortSide.EAST)
        creator.addEdgeBetweenPorts(dummyNodePort, normalNodePort)
        let originPort = middleLayer[2].getPorts()[0]
        dummyNodePort.setProperty(InternalProperties.ORIGIN, originPort)

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[0], rightLayer[0], false)

        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 0)
    }

    /// Edges in both directions:
    func test_edgesInBothDirections() {
        let leftLayer = creator.addNodesToLayer(2, creator.makeLayer())
        let middleLayer = creator.addNodesToLayer(3, creator.makeLayer())
        let rightLayer = creator.addNodesToLayer(2, creator.makeLayer())

        creator.setFixedOrderConstraint(middleLayer[2])

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[1], leftLayer[1], true)

        let normalNodePort = creator.addPortOnSide(rightLayer[1], PortSide.WEST)
        let dummyNodePort = creator.addPortOnSide(middleLayer[1], PortSide.EAST)
        creator.addEdgeBetweenPorts(dummyNodePort, normalNodePort)
        let originPort = middleLayer[2].getPorts()[0]
        dummyNodePort.setProperty(InternalProperties.ORIGIN, originPort)

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[0], leftLayer[0], true)

        let normalNodePort2 = creator.addPortOnSide(rightLayer[0], PortSide.WEST)
        let dummyNodePort2 = creator.addPortOnSide(middleLayer[0], PortSide.EAST)
        creator.addEdgeBetweenPorts(dummyNodePort2, normalNodePort2)
        let originPort2 = middleLayer[2].getPorts()[1]
        dummyNodePort2.setProperty(InternalProperties.ORIGIN, originPort2)

        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 1)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 1)
    }

    /// Multiple edges in both directions NS node:
    func test_multipleEdgesInBothDirectionsNSNode() {
        let leftLayer = creator.addNodesToLayer(2, creator.makeLayer())
        let middleLayer = creator.addNodesToLayer(3, creator.makeLayer())
        let rightLayer = creator.addNodesToLayer(2, creator.makeLayer())

        creator.setFixedOrderConstraint(middleLayer[2])

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[1], leftLayer[1], true)

        let normalNodePort = creator.addPortOnSide(rightLayer[1], PortSide.WEST)
        let dummyNodePort = creator.addPortOnSide(middleLayer[1], PortSide.EAST)
        creator.addEdgeBetweenPorts(dummyNodePort, normalNodePort)
        creator.addEdgeBetweenPorts(dummyNodePort, normalNodePort)
        let originPort = middleLayer[2].getPorts()[0]
        dummyNodePort.setProperty(InternalProperties.ORIGIN, originPort)

        creator.addNorthSouthEdge(PortSide.NORTH, middleLayer[2], middleLayer[0], rightLayer[0], false)

        let normalNodePort2 = creator.addPortOnSide(rightLayer[0], PortSide.EAST)
        let dummyNodePort2 = creator.addPortOnSide(middleLayer[0], PortSide.WEST)
        creator.addEdgeBetweenPorts(dummyNodePort2, normalNodePort2)
        creator.addEdgeBetweenPorts(dummyNodePort2, normalNodePort2)
        let originPort2 = middleLayer[2].getPorts()[1]
        dummyNodePort2.setProperty(InternalProperties.ORIGIN, originPort2)

        countCrossingsInLayerBetweenNodes(1, 0, 1)
        XCTAssertEqual(counter.getUpperLowerCrossings(), 2)
        XCTAssertEqual(counter.getLowerUpperCrossings(), 2)
    }
}
