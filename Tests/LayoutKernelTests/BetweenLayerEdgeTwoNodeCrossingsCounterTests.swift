// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.BetweenLayerEdgeTwoNodeCrossingsCounterTest

import XCTest
@testable import LayoutKernel

final class BetweenLayerEdgeTwoNodeCrossingsCounterTests: XCTestCase {

    private var creator: TestGraphCreator!
    private var crossingCounter: BetweenLayerEdgeTwoNodeCrossingsCounter!
    private var upperNode: LNode!
    private var lowerNode: LNode!
    private var layerToCountIn: Layer!
    private var nodeOrder: [[LNode]]!

    override func setUp() {
        super.setUp()
        creator = TestGraphCreator()
    }

    // MARK: - Helpers

    private func setUpperNode(_ nodeIndex: Int) {
        upperNode = layerToCountIn.getNodes()[nodeIndex]
    }

    private func setLowerNode(_ nodeIndex: Int) {
        lowerNode = layerToCountIn.getNodes()[nodeIndex]
    }

    private func assertEasternSideUpperLowerCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countEasternEdgeCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getUpperLowerCrossings(), expected,
                       "east, upper lower", file: file, line: line)
    }

    private func assertEasternSideLowerUpperCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countEasternEdgeCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getLowerUpperCrossings(), expected,
                       "east, lower upper", file: file, line: line)
    }

    private func assertWesternSideUpperLowerCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countWesternEdgeCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getUpperLowerCrossings(), expected,
                       "west, upper lower", file: file, line: line)
    }

    private func assertWesternSideLowerUpperCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countWesternEdgeCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getLowerUpperCrossings(), expected,
                       "west, lower upper", file: file, line: line)
    }

    private func assertBothSideUpperLowerCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countBothSideCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getUpperLowerCrossings(), expected,
                       "both, upper lower", file: file, line: line)
    }

    private func assertBothSideLowerUpperCrossingsIs(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        crossingCounter.countBothSideCrossings(upperNode, lowerNode)
        XCTAssertEqual(crossingCounter.getLowerUpperCrossings(), expected,
                       "both, lower upper", file: file, line: line)
    }

    // MARK: - Tests

    func test_twoNodeNoEdges() {
        creator.getTwoNodesNoConnectionGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertBothSideUpperLowerCrossingsIs(0)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_crossFormed() {
        creator.getCrossFormedGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertBothSideUpperLowerCrossingsIs(1)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(1)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_oneNode() {
        creator.getOneNodeGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(0)

        assertBothSideUpperLowerCrossingsIs(0)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_crossFormedMultipleEdgesBetweenSameNodes() {
        creator.getMultipleEdgesBetweenSameNodesGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertBothSideUpperLowerCrossingsIs(4)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(4)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_crossWithExtraEdgeInBetween() {
        creator.getCrossWithExtraEdgeInBetweenGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(2)

        assertBothSideUpperLowerCrossingsIs(1)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(1)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_ignoreInLayerEdges() {
        creator.getInLayerEdgesGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(2)

        assertBothSideUpperLowerCrossingsIs(0)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_ignoreSelfLoops() {
        creator.getCrossWithManySelfLoopsGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertBothSideUpperLowerCrossingsIs(1)
        assertBothSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(1)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
    }

    func test_moreComplexThreeLayerGraph() {
        creator.getMoreComplexThreeLayerGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertWesternSideUpperLowerCrossingsIs(1)
        assertWesternSideLowerUpperCrossingsIs(1)
        assertEasternSideUpperLowerCrossingsIs(2)
        assertEasternSideLowerUpperCrossingsIs(3)
        assertBothSideUpperLowerCrossingsIs(3)
        assertBothSideLowerUpperCrossingsIs(4)
    }

    func test_fixedPortOrder() {
        creator.getFixedPortOrderGraph()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(1)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(1)
        assertBothSideLowerUpperCrossingsIs(0)
    }

    func test_switchThreeTimes() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(4, creator.makeLayer(creator.getGraph()))
        let leftTopPort = creator.addPortOnSide(leftNodes[0], PortSide.EAST)
        let leftLowerPort = creator.addPortOnSide(leftNodes[1], PortSide.EAST)
        let rightTopPort = creator.addPortOnSide(rightNodes[0], PortSide.WEST)

        creator.addEdgeBetweenPorts(leftLowerPort, rightTopPort)
        creator.eastWestEdgeFromTo(leftLowerPort, rightNodes[2])
        creator.addEdgeBetweenPorts(leftTopPort, rightTopPort)
        creator.eastWestEdgeFromTo(leftTopPort, rightNodes[1])
        creator.eastWestEdgeFromTo(leftTopPort, rightNodes[3])

        creator.setUpIds()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(3)
        assertEasternSideLowerUpperCrossingsIs(2)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(3)
        assertBothSideLowerUpperCrossingsIs(2)
    }

    func test_intoSamePort() {
        creator.twoEdgesIntoSamePort()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[1]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 1)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(2)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(2)
        assertBothSideLowerUpperCrossingsIs(0)
    }

    func test_intoSamePortCausesCrossingsOnSwitch() {
        creator.twoEdgesIntoSamePortCrossesWhenSwitched()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(1)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(0)
        assertBothSideLowerUpperCrossingsIs(1)
    }

    func test_intoSamePortReducesCrossingsOnSwitch() {
        creator.twoEdgesIntoSamePortResolvesCrossingWhenSwitched()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(1)
        assertEasternSideLowerUpperCrossingsIs(0)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(1)
        assertBothSideLowerUpperCrossingsIs(0)
    }

    func test_intoSamePortFromEastSwitchWithFixedPortOrder() {
        creator.twoEdgesIntoSamePortFromEastWithFixedPortOrder()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideLowerUpperCrossingsIs(1)
        assertWesternSideUpperLowerCrossingsIs(0)
        assertWesternSideLowerUpperCrossingsIs(0)
        assertBothSideUpperLowerCrossingsIs(0)
        assertBothSideLowerUpperCrossingsIs(1)
    }

    func test_multipleEdgesIntoSamePort_causesNoCrossings() {
        let leftLayer = creator.makeLayer(creator.graph)
        let rightLayer = creator.makeLayer(creator.graph)

        let topLeft = creator.addNodeToLayer(leftLayer)
        let bottomLeft = creator.addNodeToLayer(leftLayer)
        let bottomRight = creator.addNodeToLayer(rightLayer)

        let bottomRightPort = creator.addPortOnSide(bottomRight, PortSide.WEST)

        creator.eastWestEdgeFromTo(topLeft, bottomRightPort)
        creator.eastWestEdgeFromTo(topLeft, bottomRightPort)
        creator.eastWestEdgeFromTo(bottomLeft, bottomRightPort)
        creator.setUpIds()
        nodeOrder = creator.getGraph().toNodeArray()
        layerToCountIn = creator.getGraph().getLayers()[0]
        crossingCounter = BetweenLayerEdgeTwoNodeCrossingsCounter(nodeOrder, 0)
        setUpperNode(0)
        setLowerNode(1)

        assertEasternSideUpperLowerCrossingsIs(0)
        assertEasternSideUpperLowerCrossingsIs(0)
    }
}
