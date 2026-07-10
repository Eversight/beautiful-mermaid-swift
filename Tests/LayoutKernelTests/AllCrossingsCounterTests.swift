// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.counting.AllCrossingsCounterTest

import XCTest
@testable import LayoutKernel

final class AllCrossingsCounterTests: XCTestCase {

    // MARK: - Helpers

    private func allCrossings(_ creator: TestGraphCreator) -> Int {
        let graph = creator.graph
        let nodeArray = graph.toNodeArray()
        var portId = 0
        for lNodes in nodeArray {
            for lNode in lNodes {
                for port in lNode.getPorts() {
                    port.id = portId
                    portId += 1
                }
            }
        }
        let gd = GraphInfoHolder(graph, .BARYCENTER, [])
        return gd.crossCounter().countAllCrossings(nodeArray)
    }

    private func switchNodesInLayer(_ upperNodeIndex: Int, _ lowerNodeIndex: Int, _ layerIndex: Int, _ graph: LGraph) {
        let layer = graph.getLayers()[layerIndex]
        var nodes = layer.nodes
        let upperNode = nodes[upperNodeIndex]
        nodes[upperNodeIndex] = nodes[lowerNodeIndex]
        nodes[lowerNodeIndex] = upperNode
        layer.nodes = nodes
    }

    // MARK: - Tests

    func testCountOneCrossing() {
        let creator = TestGraphCreator()
        _ = creator.getCrossFormedGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testCountInLayerCrossing() {
        let creator = TestGraphCreator()
        _ = creator.getInLayerEdgesGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testCountInLayerCrossingAndSwitch() {
        let creator = TestGraphCreator()
        _ = creator.getInLayerEdgesGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testCountNorthSouthCrossing() {
        let nsCreator = NorthSouthEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = nsCreator.getNorthSouthDownwardCrossingGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testCountNorthernNorthSouthCrossing() {
        let nsCreator = NorthSouthEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = nsCreator.getNorthSouthUpwardCrossingGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testNorthSouthDummyEdgeCrossing() {
        let nsCreator = NorthSouthEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = nsCreator.getSouthernNorthSouthDummyEdgeCrossingGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testSwitchAndCountTwice() {
        let creator = TestGraphCreator()
        _ = creator.getCrossFormedGraph()
        XCTAssertEqual(allCrossings(creator), 1)
        switchNodesInLayer(0, 1, 1, creator.graph)
        XCTAssertEqual(allCrossings(creator), 0)
    }

    func testTooManyInLayerCrossingsWithTheOldMethod() {
        let ilCreator = InLayerEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = ilCreator.getInLayerOneLayerNoCrossings()
        XCTAssertEqual(allCrossings(creator), 0)
    }

    func testCountCrossingsWithMultipleEdgesBetweenSameNodes() {
        let creator = TestGraphCreator()
        let left = creator.addNodesToLayer(2, creator.makeLayer())
        let right = creator.addNodesToLayer(2, creator.makeLayer())

        let rightLowerPorts = creator.addPortsOnSide(2, right[1], .WEST)
        creator.eastWestEdgeFromTo(left[0], rightLowerPorts[1])
        creator.eastWestEdgeFromTo(left[0], rightLowerPorts[0])
        let rightUpperPorts = creator.addPortsOnSide(2, right[0], .WEST)
        creator.eastWestEdgeFromTo(left[1], rightUpperPorts[1])
        creator.eastWestEdgeFromTo(left[1], rightUpperPorts[0])

        XCTAssertEqual(allCrossings(creator), 4)
    }

    func testCountCrossingsInEmptyGraph() {
        let creator = TestGraphCreator()
        _ = creator.getEmptyGraph()
        XCTAssertEqual(allCrossings(creator), 0)
    }

    func testOneNodeIsLongEdgeDummy() {
        let nsCreator = NorthSouthEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = nsCreator.getSouthernNorthSouthDummyEdgeCrossingGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testOneNodeIsLongEdgeDummyNorthern() {
        let nsCreator = NorthSouthEdgeTestGraphCreator()
        let creator = TestGraphCreator()
        creator.graph = nsCreator.getNorthernNorthSouthDummyEdgeCrossingGraph()
        XCTAssertEqual(allCrossings(creator), 1)
    }

    func testMultipleNorthSouthAndLongEdgeDummiesOnBothSides() {
        let creator = TestGraphCreator()
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer())
        let middleNodes = creator.addNodesToLayer(7, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(6, creator.makeLayer())

        creator.eastWestEdgeFromTo(leftNodes[0], middleNodes[2])
        creator.eastWestEdgeFromTo(middleNodes[2], rightNodes[2])
        creator.eastWestEdgeFromTo(leftNodes[1], middleNodes[4])
        creator.eastWestEdgeFromTo(middleNodes[4], rightNodes[3])

        creator.setAsLongEdgeDummy(middleNodes[2])
        creator.setAsLongEdgeDummy(middleNodes[4])

        creator.addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[0], rightNodes[0], false)
        creator.addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[1], rightNodes[1], false)
        creator.addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[5], rightNodes[4], false)
        creator.addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[6], rightNodes[5], false)

        XCTAssertEqual(allCrossings(creator), 4)
    }

    func testInLayerCrossingsOnFarLeft() {
        let creator = TestGraphCreator()
        let nodes = creator.addNodesToLayer(3, creator.makeLayer(creator.graph))

        creator.setFixedOrderConstraint(nodes[1])

        creator.addInLayerEdge(nodes[0], nodes[1], .WEST)
        creator.addInLayerEdge(nodes[1], nodes[2], .WEST)

        XCTAssertEqual(allCrossings(creator), 1)
    }
}
