// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.SwitchDeciderTest

import XCTest
@testable import LayoutKernel

final class SwitchDeciderTests: XCTestCase {

    private let greedyTypes: [CrossMinType] = [
        .ONE_SIDED_GREEDY_SWITCH,
        .TWO_SIDED_GREEDY_SWITCH,
    ]

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

    private func givenDecider(
        _ creator: TestGraphCreator,
        freeLayerIndex: Int,
        direction: SwitchDecider.CrossingCountSide,
        greedyType: CrossMinType
    ) -> (SwitchDecider, [[LNode]]) {
        let graph = creator.getGraph()
        let currentNodeOrder = graph.toNodeArray()
        let crossingMatrixFiller = CrossingMatrixFiller(
            greedyType, currentNodeOrder, freeLayerIndex, direction)
        let graphData = GraphInfoHolder(graph, .GREEDY_SWITCH, [])
        let decider = SwitchDecider(
            freeLayerIndex,
            currentNodeOrder,
            crossingMatrixFiller,
            SharedIntArray(repeating: 0, count: getNPorts(currentNodeOrder)),
            graphData,
            greedyType == .ONE_SIDED_GREEDY_SWITCH)
        return (decider, currentNodeOrder)
    }

    private func copyOfNodesInLayer(_ creator: TestGraphCreator, _ layerIndex: Int) -> [LNode] {
        return Array(creator.getGraph().getLayers()[layerIndex].getNodes())
    }

    private func switchNodes(
        _ currentNodeOrder: inout [[LNode]],
        _ freeLayerIndex: Int,
        _ upper: Int,
        _ lower: Int
    ) {
        let upperNode = currentNodeOrder[freeLayerIndex][upper]
        currentNodeOrder[freeLayerIndex][upper] = currentNodeOrder[freeLayerIndex][lower]
        currentNodeOrder[freeLayerIndex][lower] = upperNode
    }

    // MARK: - Tests

    func testCrossFormed() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getCrossFormedGraph()
            creator.setUpIds()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                          "crossFormed WEST \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "crossFormed EAST \(greedyType)")
        }
    }

    func testOneNode() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getOneNodeGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 0, direction: .WEST, greedyType: greedyType)
            XCTAssertFalse(decider1.doesSwitchReduceCrossings(0, 0),
                           "oneNode WEST \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertFalse(decider2.doesSwitchReduceCrossings(0, 0),
                           "oneNode EAST \(greedyType)")
        }
    }

    func testInLayerSwitchable() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getInLayerEdgesGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                          "inLayerSwitchable WEST \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 1, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "inLayerSwitchable EAST \(greedyType)")
        }
    }

    func testMultipleEdgesBetweenSameNodes() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getMultipleEdgesBetweenSameNodesGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                          "multipleEdges WEST \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "multipleEdges EAST \(greedyType)")
        }
    }

    func testSelfLoops() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getCrossWithManySelfLoopsGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                          "selfLoops WEST \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "selfLoops EAST \(greedyType)")
        }
    }

    func testNorthSouthPortCrossing() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getThreeLayerNorthSouthCrossingGraph()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(decider.doesSwitchReduceCrossings(1, 2),
                              "northSouth ONE_SIDED")
            } else {
                XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2),
                               "northSouth TWO_SIDED")
            }
        }
    }

    func testMoreComplex() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getMoreComplexThreeLayerGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertFalse(decider1.doesSwitchReduceCrossings(0, 1),
                           "moreComplex layer1 WEST (0,1) \(greedyType)")

            let (decider2, _) = givenDecider(creator, freeLayerIndex: 2, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "moreComplex layer2 WEST (0,1) \(greedyType)")
            XCTAssertFalse(decider2.doesSwitchReduceCrossings(1, 2),
                           "moreComplex layer2 WEST (1,2) \(greedyType)")

            let (decider3, _) = givenDecider(creator, freeLayerIndex: 1, direction: .EAST, greedyType: greedyType)
            XCTAssertFalse(decider3.doesSwitchReduceCrossings(0, 1),
                           "moreComplex layer1 EAST (0,1) \(greedyType)")

            let (decider4, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertFalse(decider4.doesSwitchReduceCrossings(0, 1),
                           "moreComplex layer0 EAST (0,1) \(greedyType)")
            XCTAssertTrue(decider4.doesSwitchReduceCrossings(1, 2),
                          "moreComplex layer0 EAST (1,2) \(greedyType)")
        }
    }

    func testSwitchOnlyTrueForOneSided() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getSwitchOnlyOneSided()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(decider.doesSwitchReduceCrossings(0, 1),
                              "switchOnlyOneSided ONE_SIDED")
            } else {
                XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1),
                               "switchOnlyOneSided TWO_SIDED")
            }
        }
    }

    func testSwitchOnlyTrueForOneSidedEasternSide() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getSwitchOnlyEastOneSided()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .EAST, greedyType: greedyType)
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(decider.doesSwitchReduceCrossings(0, 1),
                              "switchOnlyEast ONE_SIDED")
            } else {
                XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1),
                               "switchOnlyEast TWO_SIDED")
            }
        }
    }

    func testConstraintsPreventSwitch() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getCrossFormedGraphWithConstraintsInSecondLayer()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1),
                           "constraintsPrevent \(greedyType)")
        }
    }

    func testInLayerUnitConstraintsPreventSwitch() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getGraphWhereLayoutUnitPreventsSwitch()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 0, direction: .WEST, greedyType: greedyType)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2),
                           "inLayerUnitConstraints \(greedyType)")
        }
    }

    func testSwitchAndRecount() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getCrossFormedGraph()

            let (decider1, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                          "switchAndRecount WEST \(greedyType)")

            var (decider2, nodeOrder) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "switchAndRecount EAST \(greedyType)")

            switchNodes(&nodeOrder, 0, 0, 1)
            let layer0Nodes = copyOfNodesInLayer(creator, 0)
            decider2.notifyOfSwitch(layer0Nodes[0], layer0Nodes[1])
            XCTAssertFalse(decider2.doesSwitchReduceCrossings(0, 1),
                           "switchAndRecount after switch \(greedyType)")
        }
    }

    func testSwitchAndRecountCounterBug() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            let leftNodes = creator.addNodesToLayer(2, creator.makeLayer(creator.getGraph()))
            let rightNodes = creator.addNodesToLayer(4, creator.makeLayer(creator.getGraph()))
            let leftTopPort = creator.addPortOnSide(leftNodes[0], .EAST)
            let leftLowerPort = creator.addPortOnSide(leftNodes[1], .EAST)
            let rightTopPort = creator.addPortOnSide(rightNodes[0], .WEST)

            creator.addEdgeBetweenPorts(leftLowerPort, rightTopPort)
            creator.eastWestEdgeFromTo(leftLowerPort, rightNodes[2])
            creator.addEdgeBetweenPorts(leftTopPort, rightTopPort)
            creator.eastWestEdgeFromTo(leftTopPort, rightNodes[1])
            creator.eastWestEdgeFromTo(leftTopPort, rightNodes[3])

            creator.setUpIds()
            creator.graph = creator.getGraph()

            let freeLayerIndex = 1
            var (decider, nodeOrder) = givenDecider(creator, freeLayerIndex: freeLayerIndex, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider.doesSwitchReduceCrossings(0, 1), "counterBug (0,1) \(greedyType)")
            XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2), "counterBug (1,2) \(greedyType)")
            XCTAssertTrue(decider.doesSwitchReduceCrossings(2, 3), "counterBug (2,3) \(greedyType)")

            decider.notifyOfSwitch(nodeOrder[freeLayerIndex][0], nodeOrder[freeLayerIndex][1])
            switchNodes(&nodeOrder, freeLayerIndex, 0, 1)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1), "counterBug after switch1 (0,1) \(greedyType)")
            XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2), "counterBug after switch1 (1,2) \(greedyType)")
            XCTAssertTrue(decider.doesSwitchReduceCrossings(2, 3), "counterBug after switch1 (2,3) \(greedyType)")

            decider.notifyOfSwitch(nodeOrder[freeLayerIndex][2], nodeOrder[freeLayerIndex][3])
            switchNodes(&nodeOrder, freeLayerIndex, 2, 3)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1), "counterBug after switch2 (0,1) \(greedyType)")
            XCTAssertTrue(decider.doesSwitchReduceCrossings(1, 2), "counterBug after switch2 (1,2) \(greedyType)")
            XCTAssertFalse(decider.doesSwitchReduceCrossings(2, 3), "counterBug after switch2 (2,3) \(greedyType)")

            decider.notifyOfSwitch(nodeOrder[freeLayerIndex][1], nodeOrder[freeLayerIndex][2])
            switchNodes(&nodeOrder, freeLayerIndex, 1, 2)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1), "counterBug after switch3 (0,1) \(greedyType)")
            XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2), "counterBug after switch3 (1,2) \(greedyType)")
            XCTAssertFalse(decider.doesSwitchReduceCrossings(2, 3), "counterBug after switch3 (2,3) \(greedyType)")
        }
    }

    func testSwitchAndRecountReducedCounterBug() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            creator.graph = creator.getSwitchedProblemGraph()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            let nodesInLayer = copyOfNodesInLayer(creator, 1)
            for i in 0..<(nodesInLayer.count - 1) {
                XCTAssertFalse(decider.doesSwitchReduceCrossings(i, i + 1),
                               "reducedCounterBug switch \(i) with \(i+1) \(greedyType)")
            }
        }
    }

    func testShouldSwitchWithLongEdgeDummies() {
        for greedyType in greedyTypes {
            let creator1 = NorthSouthEdgeTestGraphCreator()
            creator1.graph = creator1.getNorthernNorthSouthDummyEdgeCrossingGraph()
            let (decider1, _) = givenDecider(creator1, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider1.doesSwitchReduceCrossings(1, 2),
                          "longEdgeDummies northern (1,2) \(greedyType)")
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(decider1.doesSwitchReduceCrossings(0, 1),
                              "longEdgeDummies northern (0,1) ONE_SIDED")
            }

            let creator2 = NorthSouthEdgeTestGraphCreator()
            creator2.graph = creator2.getSouthernNorthSouthDummyEdgeCrossingGraph()
            let (decider2, _) = givenDecider(creator2, freeLayerIndex: 1, direction: .WEST, greedyType: greedyType)
            XCTAssertTrue(decider2.doesSwitchReduceCrossings(0, 1),
                          "longEdgeDummies southern (0,1) \(greedyType)")
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(decider2.doesSwitchReduceCrossings(1, 2),
                              "longEdgeDummies southern (1,2) ONE_SIDED")
            }
        }
    }

    func testLayoutUnitConstraintPreventsSwitchWithNodeWithNorthernPorts() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getGraphLayoutUnitPreventsSwitchWithNodeWithNodeWithNorthernEdges()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(1, 2),
                           "layoutUnitNorthern \(greedyType)")
        }
    }

    func testLayoutUnitConstraintPreventsSwitchWithNodeWithSouthernPorts() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getGraphLayoutUnitPreventsSwitchWithNodeWithNodeWithSouthernEdges()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 0, direction: .EAST, greedyType: greedyType)
            XCTAssertFalse(decider.doesSwitchReduceCrossings(0, 1),
                           "layoutUnitSouthern \(greedyType)")
        }
    }

    func testLayoutUnitConstraintDoesNotPreventSwitchWithWhenOtherNodeIsLongEdgeDummy() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getGraphLayoutUnitDoesNotPreventSwitchWithLongEdgeDummy()

            let (decider, _) = givenDecider(creator, freeLayerIndex: 1, direction: .EAST, greedyType: greedyType)
            XCTAssertTrue(decider.doesSwitchReduceCrossings(0, 1),
                          "layoutUnitLongEdgeDummy \(greedyType)")
        }
    }

    func testSwitchingDummyNodesNotifiesPortSwitch() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            let leftNode = creator.addNodeToLayer(creator.makeLayer())
            let rightNodes = creator.addNodesToLayer(2, creator.makeLayer())
            let leftPorts = creator.addPortsOnSide(2, leftNode, .EAST)
            let nestedGraph = creator.nestedGraph(leftNode)
            let nestedLayer = creator.makeLayer(nestedGraph)
            let dummies = creator.addExternalPortDummiesToLayer(nestedLayer, leftPorts)
            creator.eastWestEdgeFromTo(leftPorts[0], rightNodes[1])
            creator.eastWestEdgeFromTo(leftPorts[1], rightNodes[0])

            let graph = creator.getGraph()
            let nestedNodeOrder = nestedGraph.toNodeArray()
            let crossingMatrixFiller = CrossingMatrixFiller(
                greedyType, nestedNodeOrder, 0, .EAST)
            let parentGraphData = GraphInfoHolder(graph, .GREEDY_SWITCH, [])
            let graphData = GraphInfoHolder(nestedGraph, .GREEDY_SWITCH, [parentGraphData])
            let switchDecider = SwitchDecider(
                0,
                nestedNodeOrder,
                crossingMatrixFiller,
                SharedIntArray(repeating: 0, count: getNPorts(nestedNodeOrder)),
                graphData,
                false)

            if greedyType == .TWO_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(switchDecider.doesSwitchReduceCrossings(0, 1),
                              "dummyPortSwitch before \(greedyType)")
                switchDecider.notifyOfSwitch(dummies[0], dummies[1])
                XCTAssertFalse(switchDecider.doesSwitchReduceCrossings(0, 1),
                               "dummyPortSwitch after \(greedyType)")
            }
        }
    }
}
