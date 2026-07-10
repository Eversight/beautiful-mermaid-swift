// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.AbstractBarycenterPortDistributorTest

import XCTest
@testable import LayoutKernel

final class BarycenterPortDistributorTests: XCTestCase {

    private var creator: TestGraphCreator!

    override func setUp() {
        super.setUp()
        creator = TestGraphCreator()
        _ = LayoutMetaDataService.getInstance()
    }

    // MARK: - Helper

    private func distributePortsInCompleteGraph(_ numberOfPorts: Int) {
        let gd = GraphInfoHolder(
            creator.graph,
            .BARYCENTER,
            []
        )
        let nodes = creator.graph.toNodeArray()
        for i in 0..<nodes.count {
            gd.portDistributor().distributePortsWhileSweeping(nodes, i, true)
        }
        for i in stride(from: nodes.count - 1, through: 0, by: -1) {
            gd.portDistributor().distributePortsWhileSweeping(nodes, i, false)
        }
    }

    // MARK: - Tests

    /// Cross on western side:
    /// ```
    /// *  ___
    ///  \/| |
    ///  /\| |
    /// *  |_|
    /// ```
    func test_distributePortsOnSide_GivenCrossOnWesternSide_ShouldRemoveCrossing() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let rightNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNodes[0], rightNode)
        creator.eastWestEdgeFromTo(leftNodes[1], rightNode)

        let expectedPortOrderRightNode = [rightNode.getPorts()[1], rightNode.getPorts()[0]]
            .map { ObjectIdentifier($0) }

        distributePortsInCompleteGraph(4)

        XCTAssertEqual(rightNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderRightNode)
    }

    /// Cross on both sides:
    /// ```
    /// *  ___  *
    ///  \/| |\/
    ///  /\| |/\
    /// *  |_|  *
    /// ```
    func test_distributePortsOfGraph_GivenCrossOnBothSides_ShouldRemoveCrossing() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let middleNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(middleNode, rightNodes[1])
        creator.eastWestEdgeFromTo(middleNode, rightNodes[0])
        creator.eastWestEdgeFromTo(leftNodes[0], middleNode)
        creator.eastWestEdgeFromTo(leftNodes[1], middleNode)
        creator.setUpIds()
        let expectedPortOrderMiddleNode = creator.copyPortsInIndexOrder(middleNode, 1, 0, 3, 2)
            .map { ObjectIdentifier($0) }

        distributePortsInCompleteGraph(8)

        XCTAssertEqual(middleNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderMiddleNode)
    }

    /// Cross on eastern side:
    /// ```
    /// ___
    /// | |\ /-*
    /// | | x
    /// |_|/ \-*
    /// ```
    func test_distributePortsOfGraph_GivenCrossOnEasternSide_ShouldRemoveCrossing() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNode, rightNodes[1])
        creator.eastWestEdgeFromTo(leftNode, rightNodes[0])

        let expectedPortOrderLeftNode = creator.copyPortsInIndexOrder(leftNode, 1, 0)
            .map { ObjectIdentifier($0) }

        distributePortsInCompleteGraph(4)

        XCTAssertEqual(leftNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// In-layer edge port order crossing:
    /// ```
    ///     *-----
    ///     *-\  |
    ///   ____ | |
    /// * |  |-+--
    ///   |__|-|
    /// ```
    func test_distributePortsOfGraph_GivenInLayerEdgePortOrderCrossing_ShouldRemoveIt() {
        creator.addNodeToLayer(creator.makeLayer())
        let nodes = creator.addNodesToLayer(3, creator.makeLayer())
        creator.addInLayerEdge(nodes[0], nodes[2], PortSide.EAST)
        creator.addInLayerEdge(nodes[1], nodes[2], PortSide.EAST)

        let expectedPortOrderLowerNode = creator.copyPortsInIndexOrder(nodes[2], 1, 0)
            .map { ObjectIdentifier($0) }

        distributePortsInCompleteGraph(4)

        XCTAssertEqual(nodes[2].getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLowerNode)
    }

    /// North-south port order crossing:
    /// ```
    ///     *-->*
    ///     |
    ///   *-+-->*
    ///   | |
    ///  _|_|_
    ///  |   |
    ///  |___|
    /// ```
    func test_distributePortsOfGraph_GivenNorthSouthPortOrderCrossing_ShouldSwitchPortOrder() {
        let leftNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))

        creator.addNorthSouthEdge(PortSide.NORTH, leftNodes[2], leftNodes[1], rightNodes[1], false)
        creator.addNorthSouthEdge(PortSide.NORTH, leftNodes[2], leftNodes[0], rightNodes[0], false)

        let expectedPortOrderLowerNode = [leftNodes[2].getPorts()[1], leftNodes[2].getPorts()[0]]
            .map { ObjectIdentifier($0) }

        distributePortsInCompleteGraph(6)

        XCTAssertEqual(leftNodes[2].getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLowerNode)
    }

    /// Simple cross with distributePortsWhileSweeping:
    /// ```
    /// ___  ____
    /// | |\/|  |
    /// |_|/\|  |
    ///      |--|
    /// ```
    func test_distributePortsWhileSweeping_givenSimpleCross_ShouldRemoveCrossing() {
        let leftNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNode, rightNode)
        creator.eastWestEdgeFromTo(leftNode, rightNode)
        let expectedPortRightNode = creator.copyPortsInIndexOrder(rightNode, 1, 0)
            .map { ObjectIdentifier($0) }
        creator.setUpIds()
        let nodeArray = creator.graph.toNodeArray()
        let portDist = LayerTotalPortDistributor(nodeArray.count)
        initializeAll([portDist], nodeArray)
        portDist.distributePortsWhileSweeping(nodeArray, 1, true)

        XCTAssertEqual(rightNode.getPorts().map { ObjectIdentifier($0) }, expectedPortRightNode)
    }

    // MARK: - Manual IInitializable traversal

    private func initializeAll(_ initializables: [Any], _ nodeOrder: [[LNode]]) {
        for (layerIndex, layer) in nodeOrder.enumerated() {
            for obj in initializables {
                if let pd = obj as? AbstractBarycenterPortDistributor {
                    pd.initAtLayerLevel(layerIndex, nodeOrder)
                }
            }
            for (nodeIndex, node) in layer.enumerated() {
                for obj in initializables {
                    if let pd = obj as? AbstractBarycenterPortDistributor {
                        pd.initAtNodeLevel(layerIndex, nodeIndex, nodeOrder)
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
        }
    }
}
