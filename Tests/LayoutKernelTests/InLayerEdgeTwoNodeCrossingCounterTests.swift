// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.InLayerEdgeTwoNodeCrossingCounterTest

import XCTest
@testable import LayoutKernel

// MARK: - InLayerEdgeTwoNodeCrossingCounterTests

final class InLayerEdgeTwoNodeCrossingCounterTests: XCTestCase {

    private var creator: InLayerEdgeTestGraphCreator!
    private var leftCounter: CrossingsCounter!
    private var rightCounter: CrossingsCounter!
    private var nodeOrder: [LNode]!
    private var upperLowerCrossings: Int = 0
    private var lowerUpperCrossings: Int = 0

    override func setUp() {
        super.setUp()
        creator = InLayerEdgeTestGraphCreator()
    }

    // MARK: - Helpers

    private func getNPorts(_ currentOrder: [[LNode]]) -> Int {
        var nPorts = 0
        for layer in currentOrder {
            for node in layer {
                nPorts += node.getPorts().count
            }
        }
        return nPorts
    }

    private func numberIdsAscendingly(_ nodes: [LNode]) {
        for (i, node) in nodes.enumerated() {
            node.id = i
        }
    }

    private func initCrossingCounterForLayerIndex(_ layerIndex: Int) {
        let currentOrder = creator.getGraph().toNodeArray()
        nodeOrder = currentOrder[layerIndex]
        numberIdsAscendingly(nodeOrder)
        let numPorts = getNPorts(currentOrder)
        leftCounter = CrossingsCounter([Int](repeating: 0, count: numPorts))
        rightCounter = CrossingsCounter([Int](repeating: 0, count: numPorts))
        leftCounter.initPortPositionsForInLayerCrossings(nodeOrder, .WEST)
        rightCounter.initPortPositionsForInLayerCrossings(nodeOrder, .EAST)
    }

    private func countCrossingsInLayerForUpperNodeLowerNode(_ layerIndex: Int, _ upper: Int, _ lower: Int) {
        initCrossingCounterForLayerIndex(layerIndex)
        countCrossings(upper, lower)
    }

    private func countCrossings(_ upperIndex: Int, _ lowerIndex: Int) {
        let leftResult = leftCounter.countInLayerCrossingsBetweenNodesInBothOrders(
            nodeOrder[upperIndex], nodeOrder[lowerIndex], .WEST)
        let rightResult = rightCounter.countInLayerCrossingsBetweenNodesInBothOrders(
            nodeOrder[upperIndex], nodeOrder[lowerIndex], .EAST)
        upperLowerCrossings = leftResult.getFirst()! + rightResult.getFirst()!
        lowerUpperCrossings = leftResult.getSecond()! + rightResult.getSecond()!
    }

    private func switchOrderAndNotifyCounter(_ indexOne: Int, _ indexTwo: Int) {
        leftCounter.switchNodes(nodeOrder[indexOne], nodeOrder[indexTwo], .WEST)
        rightCounter.switchNodes(nodeOrder[indexOne], nodeOrder[indexTwo], .EAST)
        let one = nodeOrder[indexOne]
        nodeOrder[indexOne] = nodeOrder[indexTwo]
        nodeOrder[indexTwo] = one
    }

    // MARK: - Tests

    func testIgnoresInBetweenLayerEdges() {
        _ = creator.getCrossFormedGraph()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testCountInLayerEdgeWithNormalEdgeCrossing() {
        _ = creator.getInLayerEdgesGraph()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testCrossingsWhenSwitched() {
        _ = creator.getInLayerEdgesGraphWhichResultsInCrossingsWhenSwitched()
        countCrossingsInLayerForUpperNodeLowerNode(1, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings")
    }

    func testInLayerEdgeOnLowerNode() {
        _ = creator.getInLayerEdgesGraph()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testSwitchNodeOrder() {
        _ = creator.getInLayerEdgesGraph()
        initCrossingCounterForLayerIndex(1)
        switchOrderAndNotifyCounter(1, 2)
        countCrossings(0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testFixedPortOrderCrossingToInBetweenLayerEdge() {
        _ = creator.getInLayerEdgesGraphWithCrossingsToBetweenLayerEdgeWithFixedPortOrder()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 2, "lowerUpperCrossings")

        switchOrderAndNotifyCounter(0, 1)
        countCrossings(0, 1)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings after switch")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings after switch")
    }

    func testFixedPortOrderCrossingsAndNormalEdgeCrossings() {
        _ = creator.getInLayerEdgesWithFixedPortOrderAndNormalEdgeCrossings()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings")

        switchOrderAndNotifyCounter(0, 1)
        countCrossings(0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings after switch")
        XCTAssertEqual(lowerUpperCrossings, 2, "lowerUpperCrossings after switch")
    }

    func testIgnoresSelfLoops() {
        _ = creator.getCrossWithManySelfLoopsGraph()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testCrossingsOnBothSides() {
        _ = creator.getInLayerCrossingsOnBothSides()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testFixedPortOrderInLayerNoCrossings() {
        _ = creator.getFixedPortOrderInLayerEdgesDontCrossEachOther()
        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testFixedPortOrderInLayerWithAlwaysRemainingCrossingsAreNotCounted() {
        _ = creator.getFixedPortOrderInLayerEdgesWithCrossings()
        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings")
    }

    func testOneNode() {
        _ = creator.getOneNodeGraph()
        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 0)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testMoreComplex() {
        _ = creator.getMoreComplexInLayerGraph()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 6, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 6, "lowerUpperCrossings")
    }

    func testDownwardInLayerEdgesOnLowerNode() {
        _ = creator.getInLayerEdgesFixedPortOrderInLayerAndInBetweenLayerCrossing()
        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 2, "lowerUpperCrossings")
    }

    func testOneLayerInLayerCrossingShouldDisappearAfterAnySwitch() {
        _ = creator.getOneLayerWithInLayerCrossings()

        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings (0,1)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (0,1)")

        countCrossingsInLayerForUpperNodeLowerNode(0, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings (1,2)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (1,2)")

        countCrossingsInLayerForUpperNodeLowerNode(0, 2, 3)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings (2,3)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (2,3)")

        switchOrderAndNotifyCounter(0, 1)
        countCrossings(0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings after switch (0,1)")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings after switch (0,1)")

        switchOrderAndNotifyCounter(0, 1)
        switchOrderAndNotifyCounter(1, 2)
        countCrossings(1, 2)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings after switch (1,2)")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings after switch (1,2)")

        switchOrderAndNotifyCounter(1, 2)
        switchOrderAndNotifyCounter(2, 3)
        countCrossings(2, 3)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings after switch (2,3)")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings after switch (2,3)")
    }

    func testMoreThanOneEdgeIntoAPort() {
        _ = creator.getInLayerEdgesMultipleEdgesIntoSinglePort()
        countCrossingsInLayerForUpperNodeLowerNode(1, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testInBetweenLayerEdgesIntoNodeWithNoFixedPortOrderCauseCrossings() {
        _ = creator.multipleInBetweenLayerEdgesIntoNodeWithNoFixedPortOrderCauseCrossings()

        countCrossingsInLayerForUpperNodeLowerNode(1, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings (0,1)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (0,1)")

        countCrossingsInLayerForUpperNodeLowerNode(1, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 2, "upperLowerCrossings (1,2)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (1,2)")
    }

    func testInLayerEdgesPassEachOther() {
        _ = creator.getInLayerOneLayerNoCrossings()

        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings (0,1)")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings (0,1)")

        countCrossingsInLayerForUpperNodeLowerNode(0, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings (1,2)")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings (1,2)")

        countCrossingsInLayerForUpperNodeLowerNode(0, 2, 3)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings (2,3)")
        XCTAssertEqual(lowerUpperCrossings, 1, "lowerUpperCrossings (2,3)")
    }

    func testFixedPortOrderCrossingToInLayerEdge() {
        _ = creator.getInLayerEdgesFixedPortOrderInLayerCrossing()
        countCrossingsInLayerForUpperNodeLowerNode(0, 1, 2)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testFixedPortOrderTwoInLayerEdgesCrossEachOther() {
        _ = creator.getFixedPortOrderTwoInLayerEdgesCrossEachOther()
        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 1, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }

    func testMultipleEdgesIntoOnePort_ShouldNotCauseCrossing() {
        let nodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let portSide: PortSide = .EAST
        let portOne = creator.addPortOnSide(nodes[0], portSide)
        let portTwo = creator.addPortOnSide(nodes[1], portSide)
        let portThree = creator.addPortOnSide(nodes[2], portSide)
        creator.addEdgeBetweenPorts(portOne, portThree)
        creator.addEdgeBetweenPorts(portTwo, portThree)

        countCrossingsInLayerForUpperNodeLowerNode(0, 0, 1)
        XCTAssertEqual(upperLowerCrossings, 0, "upperLowerCrossings")
        XCTAssertEqual(lowerUpperCrossings, 0, "lowerUpperCrossings")
    }
}
