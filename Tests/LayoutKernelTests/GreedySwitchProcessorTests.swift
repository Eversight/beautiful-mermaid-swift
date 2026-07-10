// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.GreedySwitchProcessorTest

import XCTest
@testable import LayoutKernel

final class GreedySwitchProcessorTests: XCTestCase {

    private let greedyTypes: [CrossMinType] = [
        .ONE_SIDED_GREEDY_SWITCH,
        .TWO_SIDED_GREEDY_SWITCH,
    ]

    // MARK: - Helpers

    private func copyOfNodesInLayer(_ creator: TestGraphCreator, _ layerIndex: Int) -> [LNode] {
        return Array(creator.graph.getLayers()[layerIndex].getNodes())
    }

    private func copyOfSwitchOrderOfNodesInLayer(
        _ creator: TestGraphCreator, _ nodeOne: Int, _ nodeTwo: Int, _ layerIndex: Int
    ) -> [LNode] {
        var layer = copyOfNodesInLayer(creator, layerIndex)
        let first = layer[nodeOne]
        layer[nodeOne] = layer[nodeTwo]
        layer[nodeTwo] = first
        return layer
    }

    private func getCopyWithSwitchedOrder(_ nodeOne: Int, _ nodeTwo: Int, _ layer: [LNode]) -> [LNode] {
        var switched = layer
        let first = switched[nodeOne]
        switched[nodeOne] = switched[nodeTwo]
        switched[nodeTwo] = first
        return switched
    }

    private func startGreedySwitcher(_ creator: TestGraphCreator, greedyType: CrossMinType) {
        let minimizer = LayerSweepCrossingMinimizer(greedyType)
        let monitor = BasicProgressMonitor()
        minimizer.process(creator.getGraph(), monitor)
    }

    private func nodesAreEqual(_ a: [LNode], _ b: [LNode]) -> Bool {
        guard a.count == b.count else { return false }
        for (i, node) in a.enumerated() {
            if node !== b[i] { return false }
        }
        return true
    }

    // MARK: - Tests

    func testShouldSwitchCross() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getCrossFormedGraph()

            let expectedOrderLayerOne: [LNode]
            let expectedOrderLayerTwo: [LNode]
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                expectedOrderLayerOne = copyOfNodesInLayer(creator, 0)
                expectedOrderLayerTwo = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 1)
            } else {
                expectedOrderLayerOne = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 0)
                expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)
            }

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderLayerOne),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
        }
    }

    func testConstraintsPreventSwitchInSecondLayer() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getCrossFormedGraphWithConstraintsInSecondLayer()

            let expectedOrderLayerOne = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 0)
            let expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderLayerOne),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
        }
    }

    func testConstraintsPreventAnySwitch() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getCrossFormedGraphConstraintsPreventAnySwitch()

            let expectedOrderLayerOne = copyOfNodesInLayer(creator, 0)
            let expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderLayerOne),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
        }
    }

    func testLayoutUnitConstraintPreventsSwitch() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getNodesInDifferentLayoutUnitsPreventSwitch()

            let expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer one \(greedyType)")
        }
    }

    func testOneNode() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getOneNodeGraph()
            // Should cause no errors
            _ = copyOfSwitchOrderOfNodesInLayer(creator, 0, 0, 0)
        }
    }

    func testInLayerSwitchable() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getInLayerEdgesGraph()

            let expectedOrder = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 1)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrder),
                          "inLayerSwitchable \(greedyType)")
        }
    }

    func testMultipleEdgesBetweenSameNodes() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getMultipleEdgesBetweenSameNodesGraph()

            let expectedOrderLayerOne: [LNode]
            let expectedOrderLayerTwo: [LNode]
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                expectedOrderLayerOne = copyOfNodesInLayer(creator, 0)
                expectedOrderLayerTwo = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 1)
            } else {
                expectedOrderLayerOne = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 0)
                expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)
            }

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderLayerOne),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
        }
    }

    func testSelfLoops() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            let leftLayer = creator.makeLayer(creator.getGraph())
            let rightLayer = creator.makeLayer(creator.getGraph())

            let topLeft = creator.addNodeToLayer(leftLayer)
            let bottomLeft = creator.addNodeToLayer(leftLayer)
            let topRight = creator.addNodeToLayer(rightLayer)
            let bottomRight = creator.addNodeToLayer(rightLayer)

            let topLeftPort = creator.addPortOnSide(topLeft, .EAST)
            let bottomLeftPort = creator.addPortOnSide(bottomLeft, .EAST)
            creator.setUpIds()
            let selfLoopCrossGraph = creator.getGraph()
            for layer in selfLoopCrossGraph {
                for node in layer {
                    creator.selfLoopOn(node, .EAST)
                    creator.selfLoopOn(node, .EAST)
                    creator.selfLoopOn(node, .EAST)
                    creator.selfLoopOn(node, .WEST)
                    creator.selfLoopOn(node, .WEST)
                    creator.selfLoopOn(node, .WEST)
                }
            }
            let topRightPort = creator.addPortOnSide(topRight, .WEST)
            let bottomRightPort = creator.addPortOnSide(bottomRight, .WEST)

            creator.addEdgeBetweenPorts(topLeftPort, bottomRightPort)
            creator.addEdgeBetweenPorts(bottomLeftPort, topRightPort)

            let expectedOrderLayerOne: [LNode]
            let expectedOrderLayerTwo: [LNode]
            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                expectedOrderLayerOne = copyOfNodesInLayer(creator, 0)
                expectedOrderLayerTwo = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 1)
            } else {
                expectedOrderLayerOne = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 0)
                expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)
            }

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderLayerOne),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
        }
    }

    func testNorthSouthPortCrossing() {
        for greedyType in greedyTypes {
            let creator = NorthSouthEdgeTestGraphCreator()
            creator.graph = creator.getNorthSouthDownwardCrossingGraph()

            let layerIndex = 0
            let expectedOrderTwoSided = copyOfNodesInLayer(creator, layerIndex)
            let expectedOrderOneSided = copyOfSwitchOrderOfNodesInLayer(creator, 1, 2, layerIndex)

            startGreedySwitcher(creator, greedyType: greedyType)

            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, layerIndex), expectedOrderOneSided),
                              "northSouth ONE_SIDED")
            } else {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, layerIndex), expectedOrderTwoSided),
                              "northSouth TWO_SIDED")
            }
        }
    }

    func testMoreComplex() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getMoreComplexThreeLayerGraph()

            let expectedOrderLayerTwo = copyOfNodesInLayer(creator, 1)
            let expectedOrderLayerThree = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 2)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderLayerTwo),
                          "Layer two \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 2), expectedOrderLayerThree),
                          "Layer three \(greedyType)")
        }
    }

    func testSwitchOnlyForOneSided() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getSwitchOnlyOneSided()

            let layerIndex = 1
            let expectedOrderOneSided = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, layerIndex)
            let expectedOrderTwoSided = copyOfNodesInLayer(creator, layerIndex)

            startGreedySwitcher(creator, greedyType: greedyType)

            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, layerIndex), expectedOrderOneSided),
                              "switchOnlyForOneSided ONE_SIDED")
            } else {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, layerIndex), expectedOrderTwoSided),
                              "switchOnlyForOneSided TWO_SIDED")
            }
        }
    }

    func testDoesNotWorsenCrossAmount() {
        for greedyType in greedyTypes {
            let creator = TestGraphCreator()
            _ = creator.getGraphWhichCouldBeWorsenedBySwitch()

            let expectedOrderFirstLayer = copyOfNodesInLayer(creator, 0)
            let expectedOrderSecondLayer = copyOfNodesInLayer(creator, 1)

            startGreedySwitcher(creator, greedyType: greedyType)

            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), expectedOrderFirstLayer),
                          "Layer one \(greedyType)")
            XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), expectedOrderSecondLayer),
                          "Layer two \(greedyType)")
        }
    }

    func testSwitchMoreThanOnce() {
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

            let oneSidedFirstLayer = copyOfNodesInLayer(creator, 0)
            let oneSidedFirstSwitch = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 1)
            let oneSidedSecondSwitch = getCopyWithSwitchedOrder(2, 3, oneSidedFirstSwitch)
            let oneSidedThirdSwitch = getCopyWithSwitchedOrder(1, 2, oneSidedSecondSwitch)

            let twoSidedFirstLayer = copyOfSwitchOrderOfNodesInLayer(creator, 0, 1, 0)
            let twoSidedFirstSwitch = copyOfSwitchOrderOfNodesInLayer(creator, 1, 2, 1)
            let twoSidedSecondSwitch = getCopyWithSwitchedOrder(0, 1, twoSidedFirstSwitch)

            startGreedySwitcher(creator, greedyType: greedyType)

            if greedyType == .ONE_SIDED_GREEDY_SWITCH {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), oneSidedFirstLayer),
                              "Layer one ONE_SIDED")
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), oneSidedThirdSwitch),
                              "Layer two ONE_SIDED")
            } else {
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 0), twoSidedFirstLayer),
                              "Layer one TWO_SIDED")
                XCTAssertTrue(nodesAreEqual(copyOfNodesInLayer(creator, 1), twoSidedSecondSwitch),
                              "Layer two TWO_SIDED")
            }
        }
    }
}
