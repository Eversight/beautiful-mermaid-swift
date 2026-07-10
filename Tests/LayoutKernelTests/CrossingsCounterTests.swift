// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.counting.CrossingsCounterTest

import XCTest
@testable import LayoutKernel

final class CrossingsCounterTests: XCTestCase {

    // MARK: - Helpers

    private func order(_ creator: TestGraphCreator) -> [[LNode]] {
        return creator.getGraph().toNodeArray()
    }

    private func getNumPorts(_ currentOrder: [[LNode]]) -> Int {
        var numPorts = 0
        for lNodes in currentOrder {
            for node in lNodes {
                numPorts += node.getPorts().count
            }
        }
        return numPorts
    }

    // MARK: - Between-Layer Crossing Tests

    /// Two single-node layers, two edges forming a cross => 1 crossing
    func testCountCrossingsBetweenLayers_fixedPortOrderCrossingOnTwoNodes() {
        let creator = InLayerEdgeTestGraphCreator()
        let left = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let right = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(left, right)
        creator.eastWestEdgeFromTo(left, right)

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 1)
    }

    /// 5 nodes in 1 layer, 3 in-layer edges => 1 in-layer crossing on EAST side
    func testLongInLayerCrossings() {
        let creator = InLayerEdgeTestGraphCreator()
        let nodes = creator.addNodesToLayer(5, creator.makeLayer())
        creator.addInLayerEdge(nodes[0], nodes[1], .EAST)
        creator.addInLayerEdge(nodes[1], nodes[3], .EAST)
        creator.addInLayerEdge(nodes[2], nodes[4], .EAST)

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countInLayerCrossingsOnSide(nodeOrder[0], .EAST), 1)
    }

    /// Cross-formed graph => 1 crossing between layers
    func testCountCrossingsBetweenLayers_crossFormed() {
        let creator = InLayerEdgeTestGraphCreator()
        _ = creator.getCrossFormedGraph()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 1)
    }

    /// Cross formed with multiple edges between same nodes => 4 crossings
    func testCountCrossingsBetweenLayers_crossFormedMultipleEdgesBetweenSameNodes() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftLayer = creator.makeLayer(creator.graph)
        let rightLayer = creator.makeLayer(creator.graph)

        let topLeft = creator.addNodeToLayer(leftLayer)
        let bottomLeft = creator.addNodeToLayer(leftLayer)
        let topRight = creator.addNodeToLayer(rightLayer)
        let bottomRight = creator.addNodeToLayer(rightLayer)

        let topLeftTopPort = creator.addPortOnSide(topLeft, .EAST)
        let topLeftBottomPort = creator.addPortOnSide(topLeft, .EAST)
        let bottomRightBottomPort = creator.addPortOnSide(bottomRight, .WEST)
        let bottomRightTopPort = creator.addPortOnSide(bottomRight, .WEST)
        creator.addEdgeBetweenPorts(topLeftTopPort, bottomRightTopPort)
        creator.addEdgeBetweenPorts(topLeftBottomPort, bottomRightBottomPort)

        let bottomLeftTopPort = creator.addPortOnSide(bottomLeft, .EAST)
        let bottomLeftBottomPort = creator.addPortOnSide(bottomLeft, .EAST)
        let topRightBottomPort = creator.addPortOnSide(topRight, .WEST)
        let topRightTopPort = creator.addPortOnSide(topRight, .WEST)
        creator.addEdgeBetweenPorts(bottomLeftTopPort, topRightTopPort)
        creator.addEdgeBetweenPorts(bottomLeftBottomPort, topRightBottomPort)

        let nodeOrder = order(creator)
        let gd = GraphInfoHolder(
            creator.graph,
            .BARYCENTER,
            []
        )
        _ = gd.portDistributor().distributePortsWhileSweeping(nodeOrder, 1, true)

        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 4)
    }

    /// Cross with extra edge in between => 3 crossings
    func testCountCrossingsBetweenLayers_crossWithExtraEdgeInBetween() {
        let creator = InLayerEdgeTestGraphCreator()
        _ = creator.getCrossWithExtraEdgeInBetweenGraph()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 3)
    }

    /// Self loops should be ignored => 1 crossing
    func testCountCrossingsBetweenLayers_ignoreSelfLoops() {
        let creator = InLayerEdgeTestGraphCreator()
        _ = creator.getCrossWithManySelfLoopsGraph()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 1)
    }

    /// More complex three-layer graph with port distribution => 1 crossing
    func testCountCrossingsBetweenLayers_moreComplexThreeLayerGraph() {
        let creator = InLayerEdgeTestGraphCreator()
        _ = creator.getMoreComplexThreeLayerGraph()
        let nodeOrder = order(creator)
        let gd = GraphInfoHolder(
            creator.graph,
            .BARYCENTER,
            []
        )
        _ = gd.portDistributor().distributePortsWhileSweeping(nodeOrder, 1, true)

        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 1)
    }

    /// Fixed port order graph => 1 crossing
    func testCountCrossingsBetweenLayers_fixedPortOrder() {
        let creator = InLayerEdgeTestGraphCreator()
        _ = creator.getFixedPortOrderGraph()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 1)
    }

    /// Two edges into the same port => 2 crossings
    func testCountCrossingsBetweenLayers_intoSamePort() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftLayer = creator.makeLayer(creator.graph)
        let rightLayer = creator.makeLayer(creator.graph)

        let topLeft = creator.addNodeToLayer(leftLayer)
        let bottomLeft = creator.addNodeToLayer(leftLayer)
        let topRight = creator.addNodeToLayer(rightLayer)
        let bottomRight = creator.addNodeToLayer(rightLayer)

        creator.eastWestEdgeFromTo(topLeft, bottomRight)
        let bottomLeftFirstPort = creator.addPortOnSide(bottomLeft, .EAST)
        let bottomLeftSecondPort = creator.addPortOnSide(bottomLeft, .EAST)
        let topRightFirstPort = creator.addPortOnSide(topRight, .WEST)

        creator.addEdgeBetweenPorts(bottomLeftFirstPort, topRightFirstPort)
        creator.addEdgeBetweenPorts(bottomLeftSecondPort, topRightFirstPort)
        creator.setUpIds()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))

        XCTAssertEqual(counter.countCrossingsBetweenLayers(nodeOrder[0], nodeOrder[1]), 2)
    }

    // MARK: - Between-Port Crossing Tests

    /// Western crossings on given ports => 1 crossing
    func testCountCrossingsBetweenPorts_givenWesternCrossings() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[1], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[1], rightNodes[0])

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))
        counter.initForCountingBetween(leftNodes, rightNodes)

        let result = counter.countCrossingsBetweenPortsInBothOrders(
            rightNodes[1].getPorts()[1],
            rightNodes[1].getPorts()[0]
        )
        XCTAssertEqual(result.getFirst(), 1)
    }

    /// Eastern-side crossings => 1 crossing
    func testCountCrossingsBetweenPorts_GivenCrossingsOnEasternSide() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftNodes = creator.addNodesToLayer(1, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))
        counter.initForCountingBetween(leftNodes, rightNodes)

        let result = counter.countCrossingsBetweenPortsInBothOrders(
            leftNodes[0].getPorts()[0],
            leftNodes[0].getPorts()[1]
        )
        XCTAssertEqual(result.getFirst(), 1)
    }

    /// Counting two different graphs does not interfere: 1 crossing, then 0 after port switch
    func testCountingTwoDifferentGraphs_DoesNotInterfere() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftNodes = creator.addNodesToLayer(3, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(3, creator.makeLayer())
        let leftNode = leftNodes[1]
        let leftPorts = creator.addPortsOnSide(2, leftNode, .EAST)
        creator.eastWestEdgeFromTo(leftNodes[2], rightNodes[1])
        creator.eastWestEdgeFromTo(leftPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftPorts[1], rightNodes[0])
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))
        counter.initForCountingBetween(leftNodes, rightNodes)

        let result1 = counter.countCrossingsBetweenPortsInBothOrders(
            leftNode.getPorts()[0],
            leftNode.getPorts()[1]
        )
        XCTAssertEqual(result1.getFirst(), 1)

        counter.switchPorts(leftPorts[0], leftPorts[1])
        // Swap ports in the node's port list to match Java: set(0, leftPorts[1]), set(1, leftPorts[0])
        leftNode.ports[0] = leftPorts[1]
        leftNode.ports[1] = leftPorts[0]

        let result2 = counter.countCrossingsBetweenPortsInBothOrders(
            leftNode.getPorts()[0],
            leftNode.getPorts()[1]
        )
        XCTAssertEqual(result2.getFirst(), 0)
    }

    /// Two edges into same port, counting between specific ports => 2 crossings
    func testCountCrossingsBetweenPorts_twoEdgesIntoSamePort() {
        let creator = InLayerEdgeTestGraphCreator()
        let leftLayer = creator.makeLayer()
        let rightLayer = creator.makeLayer()

        let topLeft = creator.addNodeToLayer(leftLayer)
        let bottomLeft = creator.addNodeToLayer(leftLayer)
        let topRight = creator.addNodeToLayer(rightLayer)
        let bottomRight = creator.addNodeToLayer(rightLayer)

        creator.eastWestEdgeFromTo(topLeft, bottomRight)
        let bottomLeftPort = creator.addPortOnSide(bottomLeft, .EAST)
        let topRightPort = creator.addPortOnSide(topRight, .WEST)

        creator.addEdgeBetweenPorts(bottomLeftPort, topRightPort)
        creator.addEdgeBetweenPorts(bottomLeftPort, topRightPort)
        creator.setUpIds()

        let nodeOrder = order(creator)
        let counter = CrossingsCounter([Int](repeating: 0, count: getNumPorts(nodeOrder)))
        counter.initForCountingBetween(nodeOrder[0], nodeOrder[1])

        let result = counter.countCrossingsBetweenPortsInBothOrders(
            bottomLeftPort,
            topLeft.getPorts()[0]
        )
        XCTAssertEqual(result.getFirst(), 2)
    }
}
