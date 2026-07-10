// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.InLayerEdgeTestGraphCreator

import XCTest
@testable import LayoutKernel

class InLayerEdgeTestGraphCreator: TestGraphCreator {

    func getInLayerEdgesGraphWithCrossingsToBetweenLayerEdgeWithFixedPortOrder() -> LGraph {
        let layers = makeLayers(2)
        let leftNode = addNodeToLayer(layers[0])
        let rightNodes = addNodesToLayer(2, layers[1])
        setPortOrderFixed(rightNodes[0])
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        return getGraph()
    }

    func getInLayerEdgesWithFixedPortOrderAndNormalEdgeCrossings() -> LGraph {
        let layer = makeLayers(2)
        let leftNode = addNodeToLayer(layer[0])
        let rightNodes = addNodesToLayer(3, layer[1])
        setFixedOrderConstraint(rightNodes[0])
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        addInLayerEdge(rightNodes[0], rightNodes[2], .WEST)
        eastWestEdgeFromTo(leftNode, rightNodes[1])
        return getGraph()
    }

    func getInLayerEdgesCrossingsButNoFixedOrder() -> LGraph {
        let layer = makeLayers(2)
        let leftNodes = addNodesToLayer(2, layer[0])
        let rightNodes = addNodesToLayer(2, layer[1])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[0])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        eastWestEdgeFromTo(leftNodes[1], rightNodes[1])
        return getGraph()
    }

    func getInLayerEdgesCrossingsNoFixedOrderNoEdgeBetweenUpperAndLower() -> LGraph {
        let layer = makeLayers(2)
        let leftNodes = addNodesToLayer(2, layer[0])
        let rightNodes = addNodesToLayer(3, layer[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[1])
        addInLayerEdge(rightNodes[0], rightNodes[2], .WEST)
        addInLayerEdge(rightNodes[0], rightNodes[2], .WEST)
        eastWestEdgeFromTo(leftNodes[1], rightNodes[2])
        return getGraph()
    }

    func getInLayerEdgesCrossingsNoFixedOrderNoEdgeBetweenUpperAndLowerUpsideDown() -> LGraph {
        let layer = makeLayers(2)
        let leftNodes = addNodesToLayer(2, layer[0])
        let rightNodes = addNodesToLayer(4, layer[1])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        addInLayerEdge(rightNodes[1], rightNodes[3], .WEST)
        addInLayerEdge(rightNodes[1], rightNodes[3], .WEST)
        eastWestEdgeFromTo(leftNodes[1], rightNodes[2])
        return getGraph()
    }

    func getInLayerCrossingsOnBothSides() -> LGraph {
        let layers = makeLayers(3)
        let leftNode = addNodeToLayer(layers[0])
        let middleNodes = addNodesToLayer(3, layers[1])
        let rightNode = addNodeToLayer(layers[2])
        addInLayerEdge(middleNodes[0], middleNodes[2], .EAST)
        addInLayerEdge(middleNodes[0], middleNodes[2], .WEST)
        eastWestEdgeFromTo(middleNodes[1], rightNode)
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        return getGraph()
    }

    func getInLayerEdgesFixedPortOrderInLayerAndInBetweenLayerCrossing() -> LGraph {
        let layers = makeLayers(2)
        let leftNode = addNodeToLayer(layers[0])
        let rightNodes = addNodesToLayer(3, layers[1])
        setFixedOrderConstraint(rightNodes[1])
        eastWestEdgeFromTo(leftNode, rightNodes[1])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        addInLayerEdge(rightNodes[1], rightNodes[2], .WEST)
        return getGraph()
    }

    func getInLayerEdgesFixedPortOrderInLayerCrossing() -> LGraph {
        let nodes = addNodesToLayer(3, makeLayer(getGraph()))
        setFixedOrderConstraint(nodes[1])
        addInLayerEdge(nodes[0], nodes[1], .WEST)
        addInLayerEdge(nodes[1], nodes[2], .WEST)
        return getGraph()
    }

    func getFixedPortOrderTwoInLayerEdgesCrossEachOther() -> LGraph {
        let nodes = addNodesToLayer(3, makeLayer(getGraph()))
        setFixedOrderConstraint(nodes[0])
        addInLayerEdge(nodes[0], nodes[2], .WEST)
        addInLayerEdge(nodes[0], nodes[1], .WEST)
        return getGraph()
    }

    func getInLayerEdgesDownwardGraphNoFixedOrder() -> LGraph {
        let layers = makeLayers(2)
        let leftNode = addNodeToLayer(layers[0])
        let rightNodes = addNodesToLayer(3, layers[1])
        eastWestEdgeFromTo(leftNode, rightNodes[1])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        addInLayerEdge(rightNodes[1], rightNodes[2], .WEST)
        return getGraph()
    }

    func getInLayerEdgesMultipleEdgesIntoSinglePort() -> LGraph {
        let layerTwo = makeLayer(getGraph())
        let leftNode = addNodeToLayer(layerTwo)
        let layerOne = makeLayer(getGraph())
        let rightNodes = addNodesToLayer(4, layerOne)
        addInLayerEdge(rightNodes[1], rightNodes[3], .WEST)
        let leftPort = addPortOnSide(leftNode, .EAST)
        let rightTopPort = addPortOnSide(rightNodes[0], .WEST)
        let rightMiddlePort = addPortOnSide(rightNodes[2], .WEST)
        addEdgeBetweenPorts(leftPort, rightMiddlePort)
        addEdgeBetweenPorts(rightTopPort, rightMiddlePort)
        return getGraph()
    }

    func getOneLayerWithInLayerCrossings() -> LGraph {
        let layer = makeLayer(getGraph())
        let nodes = addNodesToLayer(4, layer)
        addInLayerEdge(nodes[0], nodes[2], .WEST)
        addInLayerEdge(nodes[1], nodes[3], .WEST)
        return getGraph()
    }

    func getInLayerOneLayerNoCrossings() -> LGraph {
        let layer = makeLayer(getGraph())
        let nodes = addNodesToLayer(4, layer)
        addInLayerEdge(nodes[0], nodes[3], .WEST)
        addInLayerEdge(nodes[1], nodes[2], .WEST)
        return getGraph()
    }
}
