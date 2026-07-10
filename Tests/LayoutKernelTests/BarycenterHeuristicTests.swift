// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.BarycenterHeuristicTest

import XCTest
@testable import LayoutKernel

final class BarycenterHeuristicTests: XCTestCase {

    private var creator: TestGraphCreator!
    private var mockRandom: MockRandom!

    override func setUp() {
        super.setUp()
        creator = TestGraphCreator()
        mockRandom = creator.random
        LayoutMetaDataService.initElkReflect()
    }

    // MARK: - Helper

    private func minimizeCrossings(
        _ crossMin: BarycenterHeuristic,
        _ nodes: inout [LNode],
        _ preOrdered: Bool,
        _ randomized: Bool,
        _ forward: Bool
    ) {
        var nodeList = Array(nodes)
        crossMin.minimizeCrossings(&nodeList, preOrdered, randomized, forward)
        nodes = nodeList
    }

    /// Manually replicate Java's `IInitializable.init(List<IInitializable>, LNode[][])`.
    /// Traverses layers -> nodes -> ports -> edges, calling initAt* on each component.
    private func initializeAll(
        _ initializables: [Any],
        _ nodeOrder: [[LNode]]
    ) {
        for (layerIndex, layer) in nodeOrder.enumerated() {
            for obj in initializables {
                if let pd = obj as? AbstractBarycenterPortDistributor {
                    pd.initAtLayerLevel(layerIndex, nodeOrder)
                }
                if let cr = obj as? ForsterConstraintResolver {
                    cr.initAtLayerLevel(layerIndex, nodeOrder)
                }
                if let bh = obj as? BarycenterHeuristic {
                    bh.initAtLayerLevel(layerIndex, nodeOrder)
                }
            }
            for (nodeIndex, node) in layer.enumerated() {
                for obj in initializables {
                    if let pd = obj as? AbstractBarycenterPortDistributor {
                        pd.initAtNodeLevel(layerIndex, nodeIndex, nodeOrder)
                    }
                    if let cr = obj as? ForsterConstraintResolver {
                        cr.initAtNodeLevel(layerIndex, nodeIndex, nodeOrder)
                    }
                }
                let ports = node.getPorts()
                for portIndex in ports.indices {
                    for obj in initializables {
                        if let pd = obj as? AbstractBarycenterPortDistributor {
                            pd.initAtPortLevel(layerIndex, nodeIndex, portIndex, nodeOrder)
                        }
                    }
                }
            }
        }
        for obj in initializables {
            if let pd = obj as? AbstractBarycenterPortDistributor {
                pd.initAfterTraversal()
            }
            if let bh = obj as? BarycenterHeuristic {
                bh.initAfterTraversal()
            }
        }
    }

    // MARK: - Tests

    /// Simple cross:
    /// ```
    /// *  *
    ///  \/
    ///  /\
    /// *  *
    /// ```
    func test_minimizeCrossings_removesCrossingInSimpleCross() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[1], rightNodes[0])
        creator.setUpIds()
        var nodes = creator.graph.toNodeArray()

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        portDist.calculatePortRanks(nodes[0], .OUTPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = creator.switchOrderInArray(0, 1, nodes[1])

        minimizeCrossings(crossMin, &nodes[1], false, false, true)

        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) },
                       expectedOrder.map { ObjectIdentifier($0) },
                       "Expected crossing to be removed by switching nodes in layer 1")
    }

    /// Mock random first layer:
    /// ```
    /// *  *
    ///  \/
    ///  /\
    /// *  *
    /// ```
    func test_mockRandomizeFirstLayer() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[1], rightNodes[0])
        creator.setUpIds()

        var nodes = creator.graph.toNodeArray()
        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)
        portDist.calculatePortRanks(nodes[0], .OUTPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = nodes[0].map { ObjectIdentifier($0) }
        let expectedSwitchedOrder = creator.switchOrderInArray(0, 1, nodes[0]).map { ObjectIdentifier($0) }

        minimizeCrossings(crossMin, &nodes[0], false, true, true)
        XCTAssertEqual(nodes[0].map { ObjectIdentifier($0) }, expectedOrder)

        mockRandom.setChangeBy(-0.01)
        minimizeCrossings(crossMin, &nodes[0], false, true, true)
        XCTAssertEqual(nodes[0].map { ObjectIdentifier($0) }, expectedSwitchedOrder)
    }

    /// Filling in unknown barycenters:
    /// ```
    ///   *  *
    ///    \/
    ///    /\
    /// *-*  *
    /// ```
    func test_fillingInUnknownBarycenters() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer())
        let middleNodes = creator.addNodesToLayer(2, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(middleNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        creator.eastWestEdgeFromTo(leftNode, middleNodes[1])
        creator.setUpIds()

        var nodes = creator.graph.toNodeArray()
        let expectedSwitchedOrder = creator.switchOrderInArray(0, 1, nodes[2]).map { ObjectIdentifier($0) }
        let expectedOrderSecondLayer = nodes[1].map { ObjectIdentifier($0) }

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)
        portDist.calculatePortRanks(nodes[0], .OUTPUT)
        minimizeCrossings(crossMin, &nodes[0], false, true, true)

        portDist.calculatePortRanks(nodes[1], .OUTPUT)
        minimizeCrossings(crossMin, &nodes[1], false, false, true)
        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) }, expectedOrderSecondLayer)

        minimizeCrossings(crossMin, &nodes[2], false, false, true)
        XCTAssertEqual(nodes[2].map { ObjectIdentifier($0) }, expectedSwitchedOrder)
    }

    /// Fixed port order, simple cross:
    /// ```
    /// ____  *
    /// |  |\/
    /// |__|/\
    ///       *
    /// ```
    func test_assumingFixedPortOrder_givenSimplePortOrderCross_removesCrossingIndependentOfRandom() {
        let leftLayer = creator.makeLayer(creator.graph)
        let rightLayer = creator.makeLayer(creator.graph)

        let leftNode = creator.addNodeToLayer(leftLayer)
        let rightTopNode = creator.addNodeToLayer(rightLayer)
        let rightBottomNode = creator.addNodeToLayer(rightLayer)

        creator.eastWestEdgeFromTo(leftNode, rightBottomNode)
        creator.eastWestEdgeFromTo(leftNode, rightTopNode)
        creator.setFixedOrderConstraint(leftNode)
        creator.setUpIds()

        var nodes = creator.graph.toNodeArray()

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        portDist.calculatePortRanks(nodes[0], .OUTPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = creator.switchOrderInArray(0, 1, nodes[1]).map { ObjectIdentifier($0) }

        minimizeCrossings(crossMin, &nodes[1], false, false, true)
        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) }, expectedOrder)

        mockRandom.setChangeBy(-0.1)
        mockRandom.setNextBoolean(false)
        minimizeCrossings(crossMin, &nodes[1], false, false, true)
        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) }, expectedOrder)
    }

    /// Fixed port order cross backwards:
    /// ```
    /// *  ___
    ///  \/| |
    ///  /\|_|
    /// *
    /// ```
    func test_assumingFixedPortOrder_givenSimplePortOrderCross_removesCrossingBackwards() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.graph))
        let rightNode = creator.addNodeToLayer(creator.makeLayer(creator.graph))
        creator.eastWestEdgeFromTo(leftNodes[0], rightNode)
        creator.eastWestEdgeFromTo(leftNodes[1], rightNode)
        creator.setFixedOrderConstraint(rightNode)
        creator.setUpIds()

        var nodes = creator.graph.toNodeArray()

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        portDist.calculatePortRanks(nodes[1], .INPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = creator.switchOrderInArray(0, 1, nodes[0]).map { ObjectIdentifier($0) }

        minimizeCrossings(crossMin, &nodes[0], false, false, false)

        XCTAssertEqual(nodes[0].map { ObjectIdentifier($0) }, expectedOrder)
    }

    /// In-layer edges with fixed port order:
    /// ```
    ///       ___
    ///    ---| |
    ///    |  | |
    /// ---+--|_|
    /// |  |
    /// *--|--*
    ///    |
    ///    ---*
    /// ```
    func test_inLayerEdges() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(3, creator.makeLayer())
        creator.setFixedOrderConstraint(rightNodes[0])
        creator.eastWestEdgeFromTo(leftNode, rightNodes[0])
        creator.addInLayerEdge(rightNodes[0], rightNodes[2], PortSide.WEST)
        creator.eastWestEdgeFromTo(leftNode, rightNodes[1])
        creator.setUpIds()
        var nodes = creator.graph.toNodeArray()

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        portDist.calculatePortRanks(nodes[0], .INPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = creator.getArrayInIndexOrder(nodes[1], 2, 0, 1).map { ObjectIdentifier($0) }

        minimizeCrossings(crossMin, &nodes[1], false, false, true)

        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) }, expectedOrder)
    }

    /// North-south edges:
    /// ```
    ///   ----*
    ///   |---*
    ///   ||
    /// *-++--*
    ///   ||
    ///  ----
    ///  |__|
    /// ```
    func test_northSouthEdges() {
        let leftNodes = creator.addNodesToLayer(1, creator.makeLayer())
        let middleNodes = creator.addNodesToLayer(4, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(3, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], middleNodes[2])
        creator.eastWestEdgeFromTo(middleNodes[2], rightNodes[2])
        creator.setAsLongEdgeDummy(middleNodes[2])
        creator.addNorthSouthEdge(PortSide.NORTH, middleNodes[3], middleNodes[0], rightNodes[0], false)
        creator.addNorthSouthEdge(PortSide.NORTH, middleNodes[3], middleNodes[1], rightNodes[1], false)
        creator.setUpIds()

        var nodes = creator.graph.toNodeArray()

        let portDist = NodeRelativePortDistributor(nodes.count)
        let constraintResolver = ForsterConstraintResolver(nodes)
        initializeAll([portDist, constraintResolver], nodes)

        portDist.calculatePortRanks(nodes[0], .INPUT)
        let crossMin = BarycenterHeuristic(constraintResolver, mockRandom, portDist, nodes)
        initializeAll([crossMin], nodes)

        let expectedOrder = creator.getArrayInIndexOrder(nodes[1], 1, 0, 3, 2).map { ObjectIdentifier($0) }

        mockRandom.setChangeBy(-0.01)
        minimizeCrossings(crossMin, &nodes[1], false, false, true)

        XCTAssertEqual(nodes[1].map { ObjectIdentifier($0) }, expectedOrder)
    }
}
