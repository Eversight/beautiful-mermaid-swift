// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.NorthSouthEdgeTestGraphCreator

import XCTest
@testable import LayoutKernel

class NorthSouthEdgeTestGraphCreator: TestGraphCreator {

    func getNorthSouthUpwardCrossingGraph() -> LGraph {
        let leftNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        addNorthSouthEdge(.NORTH, leftNodes[2], leftNodes[1], rightNodes[1], false)
        addNorthSouthEdge(.NORTH, leftNodes[2], leftNodes[0], rightNodes[0], false)
        setFixedOrderConstraint(leftNodes[2])
        return getGraph()
    }

    func getNorthSouthUpwardMultipleCrossingGraph() -> LGraph {
        let leftNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        addNorthSouthEdge(.NORTH, leftNodes[3], leftNodes[2], rightNodes[2], false)
        addNorthSouthEdge(.NORTH, leftNodes[3], leftNodes[1], rightNodes[1], false)
        addNorthSouthEdge(.NORTH, leftNodes[3], leftNodes[0], rightNodes[0], false)
        setFixedOrderConstraint(leftNodes[3])
        return getGraph()
    }

    func getThreeLayerNorthSouthCrossingGraph() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        setFixedOrderConstraint(rightNode)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNode, false)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], rightNode, false)
        eastWestEdgeFromTo(leftNode, middleNodes[0])
        return getGraph()
    }

    func getNorthSouthDownwardCrossingGraph() -> LGraph {
        let leftNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[2], rightNodes[1], false)
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[1], rightNodes[0], false)
        setFixedOrderConstraint(leftNodes[0])
        return getGraph()
    }

    func getNorthSouthDownwardMultipleCrossingGraph() -> LGraph {
        let leftNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[3], rightNodes[2], false)
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[2], rightNodes[1], false)
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[1], rightNodes[0], false)
        setFixedOrderConstraint(leftNodes[0])
        return getGraph()
    }

    func getSouthernNorthSouthDummyEdgeCrossingGraph() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        setAsLongEdgeDummy(middleNodes[1])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNodes[1], true)
        return getGraph()
    }

    func getSouthernNorthSouthDummyEdgeTwoCrossingGraph() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        setAsLongEdgeDummy(middleNodes[1])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNodes[1], true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[3], rightNodes[2], true)
        return getGraph()
    }

    func getSouthernTwoDummyEdgeAndNorthSouthCrossingGraph() -> LGraph {
        let leftNodes = addNodesToLayer(2, makeLayer())
        let middleNodes = addNodesToLayer(5, makeLayer())
        let rightNodes = addNodesToLayer(4, makeLayer())
        eastWestEdgeFromTo(leftNodes[0], middleNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        setAsLongEdgeDummy(middleNodes[1])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[3])
        eastWestEdgeFromTo(middleNodes[3], rightNodes[2])
        setAsLongEdgeDummy(middleNodes[3])
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[4], rightNodes[3], true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNodes[1], true)
        return getGraph()
    }

    func getNorthernNorthSouthDummyEdgeCrossingGraph() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[1])
        setAsLongEdgeDummy(middleNodes[1])
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], rightNodes[0], true)
        return getGraph()
    }

    func getSouthPortOnNormalNodeBelowLongEdgeDummy() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[0])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[0])
        middleNodes[0].type = .LONG_EDGE
        addNorthSouthEdge(.SOUTH, middleNodes[1], middleNodes[2], rightNodes[1], false)
        return getGraph()
    }

    func getNorthPortOndNormalNodeAboveLongEdgeDummy() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[2])
        eastWestEdgeFromTo(middleNodes[2], rightNodes[1])
        middleNodes[2].type = .LONG_EDGE
        addNorthSouthEdge(.NORTH, middleNodes[1], middleNodes[0], rightNodes[0], false)
        return getGraph()
    }

    func getLongEdgeDummyAndNormalNodeWithUnusedPortsOnSouthernSide() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(2, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNode)
        setAsLongEdgeDummy(middleNodes[1])
        addPortOnSide(middleNodes[0], .SOUTH)
        addPortOnSide(middleNodes[0], .SOUTH)
        return getGraph()
    }

    func getLongEdgeDummyAndNormalNodeWithUnusedPortsOnNorthernSide() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(2, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        eastWestEdgeFromTo(leftNode, middleNodes[0])
        eastWestEdgeFromTo(middleNodes[0], rightNode)
        middleNodes[0].type = .LONG_EDGE
        addPortOnSide(middleNodes[1], .NORTH)
        addPortOnSide(middleNodes[1], .NORTH)
        return getGraph()
    }

    func getMultipleNorthSouthAndLongEdgeDummiesOnBothSides() -> LGraph {
        let leftNodes = addNodesToLayer(2, makeLayer())
        let middleNodes = addNodesToLayer(7, makeLayer())
        let rightNodes = addNodesToLayer(6, makeLayer())
        eastWestEdgeFromTo(leftNodes[0], middleNodes[2])
        eastWestEdgeFromTo(middleNodes[2], rightNodes[2])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[4])
        eastWestEdgeFromTo(middleNodes[4], rightNodes[4])
        setAsLongEdgeDummy(middleNodes[2])
        setAsLongEdgeDummy(middleNodes[4])
        addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[0], rightNodes[0], false)
        addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[1], rightNodes[1], false)
        addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[5], rightNodes[4], false)
        addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[6], rightNodes[5], false)
        return getGraph()
    }

    func getSouthernNorthSouthGraphEdgesFromEastAndWestNoCrossings() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], rightNode, false)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], leftNode, true)
        return getGraph()
    }

    func getNorthernNorthSouthGraphEdgesFromEastAndWestNoCrossings() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[2])
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], leftNode, true)
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[1], rightNode, false)
        return getGraph()
    }

    func getNorthernNorthSouthGraphEdgesFromEastAndWestNoCrossingsUpperEdgeEast() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[2])
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[1], leftNode, true)
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], rightNode, false)
        return getGraph()
    }

    func getNorthSouthEdgesFromEastAndWestAndCross() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], leftNode, true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNode, false)
        return getGraph()
    }

    func getSouthernNorthSouthEdgesBothToEast() -> LGraph {
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], rightNodes[0], false)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], rightNodes[1], false)
        return getGraph()
    }

    func getNorthSouthSouthernTwoWesternEdges() -> LGraph {
        let leftNodes = addNodesToLayer(2, makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], leftNodes[0], true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], leftNodes[1], true)
        return getGraph()
    }

    func getNorthSouthSouthernThreeWesternEdges() -> LGraph {
        let leftNodes = addNodesToLayer(3, makeLayer())
        let middleNodes = addNodesToLayer(4, makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], leftNodes[0], true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], leftNodes[1], true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[3], leftNodes[2], true)
        return getGraph()
    }

    func getNorthSouthNorthernWesternEdges() -> LGraph {
        let leftNodes = addNodesToLayer(2, makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        setFixedOrderConstraint(middleNodes[2])
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[1], leftNodes[1], true)
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], leftNodes[0], true)
        return getGraph()
    }

    func getNorthSouthNorthernEasternPortToWestWesternPortToEast() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[2])
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[1], rightNode, false)
        addNorthSouthEdge(.NORTH, middleNodes[2], middleNodes[0], leftNode, true)
        return getGraph()
    }

    func getNorthSouthAllSidesMultipleCrossings() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(7, makeLayer())
        let rightNodes = addNodesToLayer(5, makeLayer())
        setFixedOrderConstraint(middleNodes[3])
        addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[1], rightNodes[1], false)
        addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[2], leftNode, true)
        addNorthSouthEdge(.NORTH, middleNodes[3], middleNodes[0], rightNodes[0], false)
        addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[6], rightNodes[4], false)
        addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[4], rightNodes[2], false)
        addNorthSouthEdge(.SOUTH, middleNodes[3], middleNodes[5], rightNodes[3], false)
        return getGraph()
    }

    func getNorthSouthSouthernWesternPortToEastAndEasternPortToWest() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(3, makeLayer())
        let rightNode = addNodeToLayer(makeLayer())
        setFixedOrderConstraint(middleNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[2], leftNode, true)
        addNorthSouthEdge(.SOUTH, middleNodes[0], middleNodes[1], rightNode, false)
        return getGraph()
    }

    func getGraphWhereLayoutUnitPreventsSwitch() -> LGraph {
        let leftNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(2, makeLayer())
        setFixedOrderConstraint(leftNodes[0])
        setFixedOrderConstraint(leftNodes[3])
        addNorthSouthEdge(.SOUTH, leftNodes[0], leftNodes[1], rightNodes[1], false)
        addNorthSouthEdge(.NORTH, leftNodes[3], leftNodes[2], rightNodes[0], false)
        return getGraph()
    }

    func getGraphLayoutUnitPreventsSwitchWithNodeWithNodeWithNorthernEdges() -> LGraph {
        let leftNodes = addNodesToLayer(3, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        addNorthSouthEdge(.NORTH, leftNodes[1], leftNodes[0], rightNodes[0], false)
        eastWestEdgeFromTo(leftNodes[1], rightNodes[2])
        eastWestEdgeFromTo(leftNodes[2], rightNodes[1])
        return getGraph()
    }

    func getGraphLayoutUnitPreventsSwitchWithNodeWithNodeWithSouthernEdges() -> LGraph {
        let leftNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[0])
        addNorthSouthEdge(.SOUTH, leftNodes[1], leftNodes[2], rightNodes[2], false)
        return getGraph()
    }

    func getGraphLayoutUnitDoesNotPreventSwitchWithLongEdgeDummy() -> LGraph {
        let leftNode = addNodeToLayer(makeLayer())
        let middleNodes = addNodesToLayer(4, makeLayer())
        let rightNodes = addNodesToLayer(3, makeLayer())
        setAsLongEdgeDummy(middleNodes[0])
        eastWestEdgeFromTo(leftNode, middleNodes[0])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        addNorthSouthEdge(.SOUTH, middleNodes[1], middleNodes[2], rightNodes[2], false)
        return getGraph()
    }
}
