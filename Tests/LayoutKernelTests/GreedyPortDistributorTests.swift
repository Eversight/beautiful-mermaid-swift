// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.GreedyPortDistributorTest

import XCTest
@testable import LayoutKernel

final class GreedyPortDistributorTests: XCTestCase {

    private var creator: TestGraphCreator!
    private var portDist: GreedyPortDistributor!

    override func setUp() {
        super.setUp()
        creator = TestGraphCreator()
    }

    // MARK: - Helper

    private func setUpDistributor() {
        portDist = GreedyPortDistributor()
        let nodeArray = creator.graph.toNodeArray()
        initializeAll([portDist!], nodeArray)
    }

    private func portsOrderedAs(_ node: LNode, _ indices: Int...) -> [ObjectIdentifier] {
        var ordered: [ObjectIdentifier] = []
        for i in indices {
            ordered.append(ObjectIdentifier(node.getPorts()[i]))
        }
        return ordered
    }

    private func initializeAll(_ initializables: [Any], _ nodeOrder: [[LNode]]) {
        for (layerIndex, layer) in nodeOrder.enumerated() {
            for obj in initializables {
                if let pd = obj as? GreedyPortDistributor {
                    pd.initAtNodeLevel(layerIndex, 0, nodeOrder)
                }
            }
            for (nodeIndex, node) in layer.enumerated() {
                for obj in initializables {
                    if let pd = obj as? GreedyPortDistributor {
                        pd.initAtNodeLevel(layerIndex, nodeIndex, nodeOrder)
                    }
                }
                // GreedyPortDistributor has no initAtPortLevel — port counting
                // is handled via initAtNodeLevel which counts all ports on each node.
            }
        }
        for obj in initializables {
            if let pd = obj as? GreedyPortDistributor {
                pd.initAfterTraversal()
            }
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
    func test_distributePorts_GivenCrossOnWesternSide_RemoveCrossing() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let rightNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNodes[0], rightNode)
        creator.eastWestEdgeFromTo(leftNodes[1], rightNode)

        let expectedPortOrderRightNode = portsOrderedAs(rightNode, 1, 0)

        setUpDistributor()
        let improved = portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 1, true)

        XCTAssertTrue(improved)
        XCTAssertEqual(rightNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderRightNode)
    }

    /// No ports on right side:
    /// ```
    /// *  ___
    ///  \/| | *
    ///  /\| | *
    /// *  |_|
    /// ```
    func test_distributePorts_GivenNoPortsOnRightSide_NothingHappens() {
        let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let middleNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNodes[0], middleNode)
        creator.eastWestEdgeFromTo(leftNodes[1], middleNode)

        let expectedPortOrderRightNode = portsOrderedAs(middleNode, 0, 1)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 1, false)

        XCTAssertEqual(middleNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderRightNode)
    }

    /// Multiple crossings on western side:
    /// ```
    /// *    ___
    ///  \/--| |
    ///  /\ /| |
    /// *  x | |
    /// *-/ \|_|
    /// ```
    func test_distributePorts_GivenMultipleCrossingsOnWesternSide_RemoveCrossing() {
        let leftNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let rightNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        creator.eastWestEdgeFromTo(leftNodes[0], rightNode)
        creator.eastWestEdgeFromTo(leftNodes[2], rightNode)
        creator.eastWestEdgeFromTo(leftNodes[1], rightNode)

        let expectedPortOrderRightNode = portsOrderedAs(rightNode, 1, 2, 0)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 1, true)

        XCTAssertEqual(rightNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderRightNode)
    }

    /// Cross on eastern side:
    /// ```
    /// ___
    /// | |\/*
    /// |_|/\*
    /// ```
    func test_distributePorts_GivenCrossingsOnEasternSide_RemoveThem() {
        let leftNodes = creator.addNodesToLayer(1, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])

        let expectedPortOrderLeftNode = portsOrderedAs(leftNodes[0], 1, 0)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftNodes[0].getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// Fixed port order, no change:
    /// ```
    /// ___
    /// | |\/*
    /// |_|/\*
    /// ```
    func test_distributePorts_fixedPortOrder_NoChange() {
        let leftNodes = creator.addNodesToLayer(1, creator.makeLayer())
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])
        creator.setFixedOrderConstraint(leftNodes[0])

        let expectedPortOrderLeftNode = portsOrderedAs(leftNodes[0], 0, 1)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftNodes[0].getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// Double cross between compound and non-compound nodes switches ports:
    /// ```
    /// ____
    /// |*-+   *
    /// |  |\\/
    /// |*-+/\\
    /// |--|   *
    /// ```
    func test_givenDoubleCrossBetweenCompoundAndNonCompoundNodes_SwitchesPorts() {
        let leftOuterNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let leftOuterPorts = creator.addPortsOnSide(2, leftOuterNode, PortSide.EAST)
        creator.eastWestEdgeFromTo(leftOuterPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftOuterPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftOuterPorts[1], rightNodes[0])
        let leftInnerGraph = creator.nestedGraph(leftOuterNode)
        let leftInnerNodes = creator.addNodesToLayer(2, creator.makeLayer(leftInnerGraph))
        let leftInnerDummyNodes = creator.addExternalPortDummiesToLayer(creator.makeLayer(leftInnerGraph), leftOuterPorts)
        creator.eastWestEdgeFromTo(leftInnerNodes[0], leftInnerDummyNodes[0])
        creator.eastWestEdgeFromTo(leftInnerNodes[1], leftInnerDummyNodes[1])
        creator.setUpIds()

        let expectedPortOrderLeftNode = portsOrderedAs(leftOuterNode, 1, 0)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftOuterNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// Single cross between compound and non-compound nodes does not switch:
    /// ```
    /// ____
    /// |*-+  *
    /// |  |\/
    /// |*-+/\
    /// |--|  *
    /// ```
    func test_givenSingleCrossBetweenCompoundAndNonCompoundNodes_DoesNotSwitchPorts() {
        let leftOuterNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
        let leftOuterPorts = creator.addPortsOnSide(2, leftOuterNode, PortSide.EAST)
        creator.eastWestEdgeFromTo(leftOuterPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftOuterPorts[1], rightNodes[0])
        let leftInnerGraph = creator.nestedGraph(leftOuterNode)
        let leftInnerNodes = creator.addNodesToLayer(2, creator.makeLayer(leftInnerGraph))
        let leftInnerDummyNodes = creator.addExternalPortDummiesToLayer(creator.makeLayer(leftInnerGraph), leftOuterPorts)
        creator.eastWestEdgeFromTo(leftInnerNodes[0], leftInnerDummyNodes[0])
        creator.eastWestEdgeFromTo(leftInnerNodes[1], leftInnerDummyNodes[1])

        let expectedPortOrderLeftNode = portsOrderedAs(leftOuterNode, 0, 1)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftOuterNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// More hierarchical nodes, does not switch:
    func test_givenMoreHierarchicalNodes_DoesNotSwitchPorts() {
        let leftOuterNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let leftOuterPorts = creator.addPortsOnSide(3, leftOuterNode, PortSide.EAST)
        creator.eastWestEdgeFromTo(leftOuterPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftOuterPorts[1], rightNodes[0])
        creator.eastWestEdgeFromTo(leftOuterPorts[2], rightNodes[2])
        let leftInnerGraph = creator.nestedGraph(leftOuterNode)
        let leftInnerNodes = creator.addNodesToLayer(3, creator.makeLayer(leftInnerGraph))
        let leftInnerDummyNodes = creator.addExternalPortDummiesToLayer(creator.makeLayer(leftInnerGraph), leftOuterPorts)
        creator.eastWestEdgeFromTo(leftInnerNodes[0], leftInnerDummyNodes[0])
        creator.eastWestEdgeFromTo(leftInnerNodes[1], leftInnerDummyNodes[1])
        creator.eastWestEdgeFromTo(leftInnerNodes[2], leftInnerDummyNodes[2])

        let expectedPortOrderLeftNode = portsOrderedAs(leftOuterNode, 0, 1, 2)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftOuterNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// More hierarchical nodes variant 2:
    func test_givenMoreHierarchicalNodes2_DoesNotSwitchPorts() {
        let leftOuterNode = creator.addNodeToLayer(creator.makeLayer(creator.getGraph()))
        let rightNodes = creator.addNodesToLayer(3, creator.makeLayer(creator.getGraph()))
        let leftOuterPorts = creator.addPortsOnSide(3, leftOuterNode, PortSide.EAST)
        creator.eastWestEdgeFromTo(leftOuterPorts[0], rightNodes[1])
        creator.eastWestEdgeFromTo(leftOuterPorts[1], rightNodes[0])
        creator.eastWestEdgeFromTo(leftOuterPorts[2], rightNodes[2])
        let leftInnerGraph = creator.nestedGraph(leftOuterNode)
        let leftInnerNode = creator.addNodeToLayer(creator.makeLayer(leftInnerGraph))
        let rightInnerNodes = creator.addNodesToLayer(3, creator.makeLayer(leftInnerGraph))
        let dummyNodes = creator.addExternalPortDummiesToLayer(creator.makeLayer(leftInnerGraph), leftOuterPorts)
        creator.eastWestEdgeFromTo(leftInnerNode, rightInnerNodes[2])
        creator.eastWestEdgeFromTo(rightInnerNodes[0], dummyNodes[0])
        creator.eastWestEdgeFromTo(rightInnerNodes[1], dummyNodes[1])
        creator.eastWestEdgeFromTo(rightInnerNodes[2], dummyNodes[2])

        let expectedPortOrderLeftNode = portsOrderedAs(leftOuterNode, 0, 1, 2)

        setUpDistributor()
        portDist.distributePortsWhileSweeping(creator.graph.toNodeArray(), 0, false)

        XCTAssertEqual(leftOuterNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// Two hierarchical nodes in one layer:
    func test_distributePortsWhileSweeping_givenTwoHierarchicalNodesInOneLayer() {
        let leftLayer = creator.makeLayer(creator.getGraph())
        let rightLayer = creator.makeLayer(creator.getGraph())
        for _ in 0..<2 {
            let leftNodes = creator.addNodesToLayer(1, leftLayer)
            let rightNodes = creator.addNodesToLayer(2, rightLayer)
            creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
            creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])
        }
        let leftOuterNode = leftLayer.getNodes()[0]
        let expectedPortOrderLeftNode = portsOrderedAs(leftOuterNode, 1, 0)

        let nodeOrder = creator.getGraph().toNodeArray()
        setUpDistributor()
        portDist.distributePortsWhileSweeping(nodeOrder, 0, false)

        XCTAssertEqual(leftOuterNode.getPorts().map { ObjectIdentifier($0) }, expectedPortOrderLeftNode)
    }

    /// No change needed:
    /// ```
    /// ___
    /// | |--*
    /// |_|--*
    /// ```
    func test_noChange() {
        let leftLayer = creator.makeLayer(creator.getGraph())
        let rightLayer = creator.makeLayer(creator.getGraph())
        let leftNodes = creator.addNodesToLayer(1, leftLayer)
        let rightNodes = creator.addNodesToLayer(2, rightLayer)
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[0])
        creator.eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        let nodeOrder = creator.getGraph().toNodeArray()
        setUpDistributor()
        let improved = portDist.distributePortsWhileSweeping(nodeOrder, 0, false)

        XCTAssertFalse(improved)
    }
}
