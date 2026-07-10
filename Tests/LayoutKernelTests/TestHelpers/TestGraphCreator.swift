// Copyright (c) 2016, 2020 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.intermediate.greedyswitch.TestGraphCreator

import XCTest
@testable import LayoutKernel

// MARK: - MockRandom

class MockRandom: Random {
    private var current: Float = 0
    private var changeByValue: Double = 0.0001
    private var nextBooleanValue: Bool = true

    override init() {
        super.init()
    }

    override func nextBoolean() -> Bool {
        return nextBooleanValue
    }

    override func nextFloat() -> Float {
        current += Float(changeByValue)
        return current
    }

    override func nextDouble() -> Double {
        return Double(nextFloat())
    }

    func setNextBoolean(_ nb: Bool) {
        nextBooleanValue = nb
    }

    func setChangeBy(_ cb: Double) {
        changeByValue = cb
    }

    func setCurrent(_ c: Float) {
        current = c
    }
}

// MARK: - TestGraphCreator

class TestGraphCreator {
    private var portId = 0
    private var nodeId = 0
    var graph: LGraph
    private var edgeId = 0
    var random: MockRandom

    init() {
        graph = LGraph()
        random = MockRandom()
        setUpGraph(graph)
    }

    // MARK: - Setup

    @discardableResult
    func setUpGraph(_ g: LGraph) -> LGraph {
        setUpIds()
        g.setProperty(LayeredOptions.EDGE_ROUTING, EdgeRouting.ORTHOGONAL)
        g.setProperty(InternalProperties.RANDOM, random)
        g.setProperty(LayeredOptions.HIERARCHY_HANDLING, HierarchyHandling.INCLUDE_CHILDREN)
        return g
    }

    func getGraph() -> LGraph {
        setUpGraph(graph)
        return graph
    }

    // MARK: - setUpIds

    func setUpIds() {
        var graphs: [LGraph] = [graph]
        while !graphs.isEmpty {
            var lId = 0
            var pId = 0
            let g = graphs.removeFirst()
            for l in g.getLayers() {
                l.id = lId
                lId += 1
                var i = 0
                for n in l.getNodes() {
                    if let nestedGraph = n.getNestedGraph() {
                        graphs.append(nestedGraph)
                    }
                    n.id = i
                    i += 1
                    for p in n.getPorts() {
                        p.id = pId
                        pId += 1
                    }
                }
            }
        }
    }

    // MARK: - Layer Creation

    @discardableResult
    func makeLayer(_ g: LGraph) -> Layer {
        let layer = Layer(g)
        g.layers.append(layer)
        return layer
    }

    @discardableResult
    func makeLayer() -> Layer {
        return makeLayer(graph)
    }

    @discardableResult
    func makeLayers(_ amount: Int) -> [Layer] {
        return makeLayers(amount, graph)
    }

    @discardableResult
    func makeLayers(_ amount: Int, _ g: LGraph) -> [Layer] {
        var layers = [Layer]()
        for _ in 0..<amount {
            layers.append(makeLayer(g))
        }
        return layers
    }

    // MARK: - Node Creation

    @discardableResult
    func addNodeToLayer(_ layer: Layer) -> LNode {
        let node = LNode(layer.getGraph())
        node.setLayer(layer)
        node.id = nodeId
        nodeId += 1
        node.type = .NORMAL
        return node
    }

    @discardableResult
    func addNodesToLayer(_ amountOfNodes: Int, _ layer: Layer) -> [LNode] {
        var nodes = [LNode]()
        for _ in 0..<amountOfNodes {
            nodes.append(addNodeToLayer(layer))
        }
        return nodes
    }

    // MARK: - Edge Creation

    func eastWestEdgeFromTo(_ left: LNode, _ right: LNode) {
        let leftPort = addPortOnSide(left, .EAST)
        let rightPort = addPortOnSide(right, .WEST)
        addEdgeBetweenPorts(leftPort, rightPort)
    }

    func eastWestEdgeFromTo(_ leftPort: LPort, _ rightNode: LNode) {
        let rightPort = addPortOnSide(rightNode, .WEST)
        addEdgeBetweenPorts(leftPort, rightPort)
    }

    func eastWestEdgeFromTo(_ left: LNode, _ right: LPort) {
        let leftPort = addPortOnSide(left, .EAST)
        addEdgeBetweenPorts(leftPort, right)
    }

    func eastWestEdgesFromTo(_ numberOfEdges: Int, _ left: LNode, _ right: LNode) {
        for _ in 0..<numberOfEdges {
            eastWestEdgeFromTo(left, right)
        }
    }

    func addEdgeBetweenPorts(_ from: LPort, _ to: LPort) {
        let edge = LEdge()
        edge.setSource(from)
        edge.setTarget(to)
        edge.id = edgeId
        edgeId += 1
    }

    func addInLayerEdge(_ nodeOne: LNode, _ nodeTwo: LNode, _ portSide: PortSide) {
        let portOne = addPortOnSide(nodeOne, portSide)
        let portTwo = addPortOnSide(nodeTwo, portSide)
        addEdgeBetweenPorts(portOne, portTwo)
    }

    func addInLayerEdge(_ nodeOne: LNode, _ portTwo: LPort, _ portSide: PortSide) {
        let portOne = addPortOnSide(nodeOne, portSide)
        addEdgeBetweenPorts(portOne, portTwo)
    }

    func addInLayerEdge(_ portOne: LPort, _ nodeTwo: LNode) {
        let portTwo = addPortOnSide(nodeTwo, portOne.getSide())
        addEdgeBetweenPorts(portOne, portTwo)
    }

    // MARK: - Port Creation

    @discardableResult
    func addPortOnSide(_ node: LNode, _ portSide: PortSide) -> LPort {
        let port = addPortTo(node)
        port.setSide(portSide)
        let constraints: PortConstraints = node.getProperty(LayeredOptions.PORT_CONSTRAINTS) ?? .FREE
        if !constraints.isSideFixed() {
            node.setProperty(LayeredOptions.PORT_CONSTRAINTS, PortConstraints.FIXED_SIDE)
        }
        return port
    }

    @discardableResult
    func addPortsOnSide(_ n: Int, _ node: LNode, _ portSide: PortSide) -> [LPort] {
        var ports = [LPort]()
        for _ in 0..<n {
            ports.append(addPortOnSide(node, portSide))
        }
        return ports
    }

    private func addPortTo(_ node: LNode) -> LPort {
        let port = LPort()
        port.setNode(node)
        port.id = portId
        portId += 1
        return port
    }

    // MARK: - Self-Loops

    func selfLoopOn(_ node: LNode, _ side: PortSide) {
        let p1 = addPortOnSide(node, side)
        let p2 = addPortOnSide(node, side)
        addEdgeBetweenPorts(p1, p2)
    }

    // MARK: - Constraints

    func setInLayerOrderConstraint(_ thisNode: LNode, _ beforeThisNode: LNode) {
        var list: [LNode] = thisNode.getProperty(InternalProperties.IN_LAYER_SUCCESSOR_CONSTRAINTS) ?? []
        list.append(beforeThisNode)
        thisNode.setProperty(InternalProperties.IN_LAYER_SUCCESSOR_CONSTRAINTS, list as Any)
    }

    @discardableResult
    func setFixedOrderConstraint(_ node: LNode) -> LNode {
        node.setProperty(LayeredOptions.PORT_CONSTRAINTS, PortConstraints.FIXED_ORDER)
        return node
    }

    func setFixedOrderConstraint(_ nodes: [LNode]) {
        for n in nodes {
            setFixedOrderConstraint(n)
        }
    }

    func setPortOrderFixed(_ node: LNode) {
        setFixedOrderConstraint(node)
        var gps: Set<GraphProperties> = graph.getProperty(InternalProperties.GRAPH_PROPERTIES) ?? []
        gps.insert(.NON_FREE_PORTS)
        graph.setProperty(InternalProperties.GRAPH_PROPERTIES, gps as Any)
    }

    // MARK: - Node Type Setters

    func setAsNorthSouthNode(_ node: LNode) {
        node.type = .NORTH_SOUTH_PORT
    }

    func setAsLongEdgeDummy(_ node: LNode) {
        node.type = .LONG_EDGE
        node.setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nil)
    }

    // MARK: - North-South Dummy Edge Builder

    func addNorthSouthEdge(
        _ side: PortSide,
        _ nodeWithNSPorts: LNode,
        _ northSouthDummy: LNode,
        _ nodeWithEastWestPorts: LNode,
        _ nodeWithEastWestPortsIsOrigin: Bool
    ) {
        northSouthDummy.type = .NORTH_SOUTH_PORT
        northSouthDummy.setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, nodeWithNSPorts as Any)

        let normalNodeEastOfNsPortNode = nodeWithEastWestPorts.getLayer()!.getIndex() < nodeWithNSPorts.getLayer()!.getIndex()
        let direction: PortSide = normalNodeEastOfNsPortNode ? .WEST : .EAST

        let dummyPort = addPortOnSide(northSouthDummy, direction)
        let normalPort = addPortOnSide(nodeWithEastWestPorts,
            direction == .WEST ? .EAST : .WEST)

        let originPort = addPortOnSide(nodeWithNSPorts, side)
        northSouthDummy.setProperty(InternalProperties.ORIGIN, nodeWithNSPorts as Any)
        dummyPort.setProperty(InternalProperties.ORIGIN, originPort as Any)
        originPort.setProperty(InternalProperties.PORT_DUMMY, northSouthDummy as Any)

        if nodeWithEastWestPortsIsOrigin {
            addEdgeBetweenPorts(normalPort, dummyPort)
        } else {
            addEdgeBetweenPorts(dummyPort, normalPort)
        }

        var barycenterAssociates: [LNode] = nodeWithNSPorts.getProperty(InternalProperties.BARYCENTER_ASSOCIATES) ?? []
        barycenterAssociates.append(northSouthDummy)
        nodeWithNSPorts.setProperty(InternalProperties.BARYCENTER_ASSOCIATES, barycenterAssociates as Any)

        if side == .NORTH {
            setInLayerOrderConstraint(northSouthDummy, nodeWithNSPorts)
        } else {
            setInLayerOrderConstraint(nodeWithNSPorts, northSouthDummy)
        }
    }

    // MARK: - External Port Dummies

    @discardableResult
    func addExternalPortDummyNodeToLayer(_ layer: Layer, _ port: LPort) -> LNode {
        let dummy = addNodeToLayer(layer)
        dummy.setProperty(InternalProperties.ORIGIN, port as Any)
        dummy.type = .EXTERNAL_PORT
        dummy.setProperty(InternalProperties.EXT_PORT_SIDE, port.getSide())
        port.setProperty(InternalProperties.PORT_DUMMY, dummy as Any)
        port.setProperty(InternalProperties.INSIDE_CONNECTIONS, true)
        var gps: Set<GraphProperties> = graph.getProperty(InternalProperties.GRAPH_PROPERTIES) ?? []
        gps.insert(.EXTERNAL_PORTS)
        graph.setProperty(InternalProperties.GRAPH_PROPERTIES, gps as Any)
        return dummy
    }

    @discardableResult
    func addExternalPortDummiesToLayer(_ layer: Layer, _ ports: [LPort]) -> [LNode] {
        var dummies = [LNode?](repeating: nil, count: ports.count)
        for i in 0..<ports.count {
            let index = ports[i].getSide() == .EAST ? i : ports.count - 1 - i
            dummies[index] = addExternalPortDummyNodeToLayer(layer, ports[i])
        }
        return dummies.map { $0! }
    }

    // MARK: - Nested Graph

    @discardableResult
    func nestedGraph(_ node: LNode) -> LGraph {
        if let existing = node.getNestedGraph() {
            return existing
        }
        node.setProperty(InternalProperties.COMPOUND_NODE, true)
        let nested = LGraph()
        _ = setUpGraph(nested)
        node.setNestedGraph(nested)
        nested.parentNode = node
        return nested
    }

    // MARK: - getCurrentOrder

    func getCurrentOrder(_ g: LGraph) -> [[LNode]] {
        return g.toNodeArray()
    }

    // MARK: - List Manipulation Helpers

    func getListCopyInIndexOrder<T>(_ li: [T], _ indices: Int...) -> [T] {
        var r = [T]()
        for i in indices {
            r.append(li[i])
        }
        return r
    }

    func getArrayInIndexOrder<T>(_ arr: [T], _ indices: Int...) -> [T] {
        var r = arr
        for i in 0..<indices.count {
            r[i] = arr[indices[i]]
        }
        return r
    }

    func copyOfListSwitchingOrder<T>(_ i: Int, _ j: Int, _ list: [T]) -> [T] {
        var copy = list
        copy[i] = list[j]
        copy[j] = list[i]
        return copy
    }

    func switchOrderInArray<T>(_ i: Int, _ j: Int, _ arr: [T]) -> [T] {
        var copy = arr
        copy[i] = arr[j]
        copy[j] = arr[i]
        return copy
    }

    @discardableResult
    func switchOrderOfNodesInLayer(_ nodeOne: Int, _ nodeTwo: Int, _ layer: Layer) -> [LNode] {
        var nodes = layer.nodes
        let tmp = nodes[nodeOne]
        nodes[nodeOne] = nodes[nodeTwo]
        nodes[nodeTwo] = tmp
        layer.nodes = nodes
        return layer.nodes
    }

    func copyOfNodesInLayer(_ layerIndex: Int) -> [LNode] {
        return Array(graph.getLayers()[layerIndex].getNodes())
    }

    func copyOfSwitchOrderOfNodesInLayer(_ nodeOne: Int, _ nodeTwo: Int, _ layerIndex: Int) -> [LNode] {
        return copyOfListSwitchingOrder(nodeOne, nodeTwo, copyOfNodesInLayer(layerIndex))
    }

    func getCopyWithSwitchedOrder(_ nodeOne: Int, _ nodeTwo: Int, _ layer: [LNode]) -> [LNode] {
        return copyOfListSwitchingOrder(nodeOne, nodeTwo, layer)
    }

    func copyPortsInIndexOrder(_ node: LNode, _ indices: Int...) -> [LPort] {
        var ports = [LPort]()
        for i in indices {
            ports.append(node.getPorts()[i])
        }
        return ports
    }

    // MARK: - setOnAllGraphs

    func setOnAllGraphs(_ prop: IProperty, _ val: Any?, _ g: LGraph) {
        g.setProperty(prop, val)
        for l in g.getLayers() {
            for n in l.getNodes() {
                if let nestedGraph = n.getNestedGraph() {
                    setOnAllGraphs(prop, val, nestedGraph)
                }
            }
        }
    }

    // MARK: - Random Getter/Setter

    func getRandom() -> MockRandom {
        return random
    }

    func setRandom(_ r: MockRandom) {
        random = r
    }

    // MARK: - Graph Factory Methods

    func getEmptyGraph() -> LGraph {
        return getGraph()
    }

    func getTwoNodesNoConnectionGraph() -> LGraph {
        let layer = makeLayer()
        addNodesToLayer(2, layer)
        return getGraph()
    }

    func getCrossFormedGraph() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNodes = addNodesToLayer(2, leftLayer)
        let rightNodes = addNodesToLayer(2, rightLayer)
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[0])
        return getGraph()
    }

    func multipleEdgesAndSingleEdge() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNodes = addNodesToLayer(2, leftLayer)
        let rightNodes = addNodesToLayer(2, rightLayer)
        eastWestEdgesFromTo(2, leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[1])
        return getGraph()
    }

    func getCrossFormedGraphWithConstraintsInSecondLayer() -> LGraph {
        _ = getCrossFormedGraph()
        let rightLayer = graph.getLayers()[1]
        let top = rightLayer.getNodes()[0]
        let bottom = rightLayer.getNodes()[1]
        setInLayerOrderConstraint(top, bottom)
        return getGraph()
    }

    func getCrossFormedGraphConstraintsPreventAnySwitch() -> LGraph {
        _ = getCrossFormedGraphWithConstraintsInSecondLayer()
        let leftLayer = graph.getLayers()[0]
        let top = leftLayer.getNodes()[0]
        let bottom = leftLayer.getNodes()[1]
        setInLayerOrderConstraint(top, bottom)
        return getGraph()
    }

    func getOneNodeGraph() -> LGraph {
        addNodeToLayer(makeLayer())
        return getGraph()
    }

    func getInLayerEdgesGraph() -> LGraph {
        let leftLayer = makeLayer()
        let middleLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNode = addNodeToLayer(leftLayer)
        let middleNodes = addNodesToLayer(3, middleLayer)
        let rightNode = addNodeToLayer(rightLayer)
        // add east side ports first to get expected port ordering
        eastWestEdgeFromTo(middleNodes[1], rightNode)
        eastWestEdgeFromTo(leftNode, middleNodes[1])
        addInLayerEdge(middleNodes[0], middleNodes[2], .WEST)
        setUpIds()
        return graph
    }

    func getInLayerEdgesGraphWhichResultsInCrossingsWhenSwitched() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNode = addNodeToLayer(leftLayer)
        let rightNodes = addNodesToLayer(3, rightLayer)
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        eastWestEdgeFromTo(leftNode, rightNodes[2])
        return getGraph()
    }

    func getMultipleEdgesBetweenSameNodesGraph() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNodes = addNodesToLayer(2, leftLayer)
        let rightNodes = addNodesToLayer(2, rightLayer)
        eastWestEdgesFromTo(2, leftNodes[0], rightNodes[1])
        eastWestEdgesFromTo(2, leftNodes[1], rightNodes[0])
        return getGraph()
    }

    func getCrossWithExtraEdgeInBetweenGraph() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNodes = addNodesToLayer(2, leftLayer)
        let rightNodes = addNodesToLayer(3, rightLayer)
        eastWestEdgeFromTo(leftNodes[0], rightNodes[2])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[0])
        return getGraph()
    }

    func getCrossWithManySelfLoopsGraph() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let topLeft = addNodeToLayer(leftLayer)
        let bottomLeft = addNodeToLayer(leftLayer)
        let topRight = addNodeToLayer(rightLayer)
        let bottomRight = addNodeToLayer(rightLayer)
        let topLeftPort = addPortOnSide(topLeft, .EAST)
        let bottomLeftPort = addPortOnSide(bottomLeft, .EAST)
        setUpIds()
        for l in graph.getLayers() {
            for n in l.getNodes() {
                selfLoopOn(n, .EAST)
                selfLoopOn(n, .EAST)
                selfLoopOn(n, .EAST)
                selfLoopOn(n, .WEST)
                selfLoopOn(n, .WEST)
                selfLoopOn(n, .WEST)
            }
        }
        let topRightPort = addPortOnSide(topRight, .WEST)
        let bottomRightPort = addPortOnSide(bottomRight, .WEST)
        addEdgeBetweenPorts(topLeftPort, bottomRightPort)
        addEdgeBetweenPorts(bottomLeftPort, topRightPort)
        return graph
    }

    func getMoreComplexThreeLayerGraph() -> LGraph {
        let leftLayer = makeLayer()
        let middleLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNodes = addNodesToLayer(3, leftLayer)
        let middleNodes = addNodesToLayer(2, middleLayer)
        let rightNodes = addNodesToLayer(3, rightLayer)
        let leftMiddleNodePort = addPortOnSide(leftNodes[1], .EAST)
        let middleLowerNodePortEast = addPortOnSide(middleNodes[1], .EAST)
        let middleUpperNodePortEast = addPortOnSide(middleNodes[0], .EAST)
        let rightUpperNodePort = addPortOnSide(rightNodes[0], .WEST)
        let rightMiddleNodePort = addPortOnSide(rightNodes[1], .WEST)
        setUpIds()
        addEdgeBetweenPorts(middleUpperNodePortEast, rightUpperNodePort)
        addEdgeBetweenPorts(middleUpperNodePortEast, rightMiddleNodePort)
        addEdgeBetweenPorts(middleUpperNodePortEast, rightMiddleNodePort)
        eastWestEdgeFromTo(middleLowerNodePortEast, rightNodes[2])
        eastWestEdgeFromTo(leftMiddleNodePort, middleNodes[0])
        eastWestEdgeFromTo(middleNodes[1], rightUpperNodePort)
        eastWestEdgeFromTo(leftMiddleNodePort, middleNodes[1])
        eastWestEdgeFromTo(leftNodes[2], middleNodes[0])
        eastWestEdgeFromTo(leftNodes[0], middleNodes[0])
        setUpIds()
        return graph
    }

    func getFixedPortOrderGraph() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNode = addNodeToLayer(leftLayer)
        let rightNodes = addNodesToLayer(2, rightLayer)
        setFixedOrderConstraint(leftNode)
        eastWestEdgeFromTo(leftNode, rightNodes[1])
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        return getGraph()
    }

    func getGraphNoCrossingsDueToPortOrderNotFixed() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNode = addNodeToLayer(leftLayer)
        let rightNodes = addNodesToLayer(2, rightLayer)
        eastWestEdgeFromTo(leftNode, rightNodes[1])
        eastWestEdgeFromTo(leftNode, rightNodes[0])
        return getGraph()
    }

    func getSwitchOnlyOneSided() -> LGraph {
        let layers = makeLayers(3)
        let leftNodes = addNodesToLayer(2, layers[0])
        let middleNodes = addNodesToLayer(2, layers[1])
        let rightNodes = addNodesToLayer(2, layers[2])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[0])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[0], middleNodes[1])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[0])
        setUpIds()
        return graph
    }

    func getSwitchOnlyEastOneSided() -> LGraph {
        let layers = makeLayers(3)
        let leftNodes = addNodesToLayer(2, layers[0])
        let middleNodes = addNodesToLayer(2, layers[1])
        let rightNodes = addNodesToLayer(2, layers[2])
        eastWestEdgeFromTo(leftNodes[0], middleNodes[0])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[1])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        setUpIds()
        return graph
    }

    func getFixedPortOrderInLayerEdgesDontCrossEachOther() -> LGraph {
        let layer = makeLayer()
        let nodes = addNodesToLayer(2, layer)
        setFixedOrderConstraint(nodes[0])
        setFixedOrderConstraint(nodes[1])
        let top0Port = addPortOnSide(nodes[0], .EAST)
        let bottom0Port = addPortOnSide(nodes[0], .EAST)
        let top1Port = addPortOnSide(nodes[1], .EAST)
        let bottom1Port = addPortOnSide(nodes[1], .EAST)
        addEdgeBetweenPorts(bottom0Port, top1Port)
        addEdgeBetweenPorts(top0Port, bottom1Port)
        return getGraph()
    }

    func getFixedPortOrderInLayerEdgesWithCrossings() -> LGraph {
        let layer = makeLayer()
        let nodes = addNodesToLayer(2, layer)
        setFixedOrderConstraint(nodes[0])
        setFixedOrderConstraint(nodes[1])
        addInLayerEdge(nodes[0], nodes[1], .EAST)
        addInLayerEdge(nodes[0], nodes[1], .EAST)
        setUpIds()
        return graph
    }

    func getMoreComplexInLayerGraph() -> LGraph {
        let layers = makeLayers(3)
        let leftNodes = addNodesToLayer(4, layers[0])
        let middleNodes = addNodesToLayer(3, layers[1])
        let rightNode = addNodeToLayer(layers[2])
        setFixedOrderConstraint(middleNodes[0])
        setFixedOrderConstraint(middleNodes[1])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[0])
        eastWestEdgeFromTo(leftNodes[3], middleNodes[1])
        eastWestEdgeFromTo(leftNodes[2], middleNodes[1])
        addInLayerEdge(middleNodes[0], middleNodes[1], .WEST)
        eastWestEdgeFromTo(leftNodes[0], middleNodes[0])
        addInLayerEdge(middleNodes[0], middleNodes[2], .WEST)
        addInLayerEdge(middleNodes[0], middleNodes[1], .EAST)
        eastWestEdgeFromTo(middleNodes[0], rightNode)
        setUpIds()
        return graph
    }

    func getGraphWhichCouldBeWorsenedBySwitch() -> LGraph {
        let layers = makeLayers(3)
        let leftNodes = addNodesToLayer(2, layers[0])
        let middleNodes = addNodesToLayer(2, layers[1])
        let rightNodes = addNodesToLayer(2, layers[2])
        setInLayerOrderConstraint(leftNodes[0], leftNodes[1])
        setInLayerOrderConstraint(rightNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[0], middleNodes[0])
        eastWestEdgeFromTo(leftNodes[0], middleNodes[1])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[0])
        eastWestEdgeFromTo(leftNodes[1], middleNodes[1])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[0])
        eastWestEdgeFromTo(middleNodes[0], rightNodes[1])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[0])
        eastWestEdgeFromTo(middleNodes[1], rightNodes[1])
        return getGraph()
    }

    func getNodesInDifferentLayoutUnitsPreventSwitch() -> LGraph {
        let layers = makeLayers(2)
        let leftNode = addNodeToLayer(layers[0])
        let rightNodes = addNodesToLayer(3, layers[1])
        setAsNorthSouthNode(rightNodes[1])
        rightNodes[1].setProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT, rightNodes[0] as Any)
        eastWestEdgeFromTo(leftNode, rightNodes[2])
        return getGraph()
    }

    func multipleInBetweenLayerEdgesIntoNodeWithNoFixedPortOrder() -> LGraph {
        let layers = makeLayers(2)
        let leftNodes = addNodesToLayer(2, layers[0])
        let rightNodes = addNodesToLayer(2, layers[1])
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[1])
        return getGraph()
    }

    func multipleInBetweenLayerEdgesIntoNodeWithNoFixedPortOrderCauseCrossings() -> LGraph {
        let leftLayer = makeLayer()
        let leftNodes = addNodesToLayer(2, leftLayer)
        let rightLayer = makeLayer()
        let rightNodes = addNodesToLayer(3, rightLayer)
        addInLayerEdge(rightNodes[0], rightNodes[2], .WEST)
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        setUpIds()
        return graph
    }

    func getSwitchedProblemGraph() -> LGraph {
        let leftNodes = addNodesToLayer(2, makeLayer())
        let rightNodes = addNodesToLayer(4, makeLayer())
        eastWestEdgeFromTo(leftNodes[1], rightNodes[2])
        eastWestEdgeFromTo(leftNodes[1], rightNodes[3])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[0])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[1])
        eastWestEdgeFromTo(leftNodes[0], rightNodes[2])
        setUpIds()
        return graph
    }

    func twoEdgesIntoSamePort() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let topLeft = addNodeToLayer(leftLayer)
        let bottomLeft = addNodeToLayer(leftLayer)
        let topRight = addNodeToLayer(rightLayer)
        let bottomRight = addNodeToLayer(rightLayer)
        eastWestEdgeFromTo(topLeft, bottomRight)
        let bottomLeftFirstPort = addPortOnSide(bottomLeft, .EAST)
        let bottomLeftSecondPort = addPortOnSide(bottomLeft, .EAST)
        let topRightFirstPort = addPortOnSide(topRight, .WEST)
        let topRightSecondPort = addPortOnSide(topRight, .WEST)
        addEdgeBetweenPorts(bottomLeftFirstPort, topRightFirstPort)
        addEdgeBetweenPorts(bottomLeftSecondPort, topRightSecondPort)
        setUpIds()
        return graph
    }

    func twoEdgesIntoSamePortCrossesWhenSwitched() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let topLeft = addNodeToLayer(leftLayer)
        let bottomLeft = addNodeToLayer(leftLayer)
        let topRight = addNodeToLayer(rightLayer)
        let bottomRight = addNodeToLayer(rightLayer)
        let topRightPort = addPortOnSide(topRight, .WEST)
        let bottomLeftPort = addPortOnSide(bottomLeft, .EAST)
        addEdgeBetweenPorts(bottomLeftPort, topRightPort)
        let topLeftPort = addPortOnSide(topLeft, .EAST)
        addEdgeBetweenPorts(topLeftPort, topRightPort)
        eastWestEdgeFromTo(bottomLeft, bottomRight)
        setUpIds()
        return graph
    }

    func twoEdgesIntoSamePortResolvesCrossingWhenSwitched() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let topLeft = addNodeToLayer(leftLayer)
        let bottomLeft = addNodeToLayer(leftLayer)
        let topRight = addNodeToLayer(rightLayer)
        let bottomRight = addNodeToLayer(rightLayer)
        let topLeftPort = addPortOnSide(topLeft, .EAST)
        let bottomLeftPort = addPortOnSide(bottomLeft, .EAST)
        let bottomRightPort = addPortOnSide(bottomRight, .WEST)
        addEdgeBetweenPorts(topLeftPort, bottomRightPort)
        addEdgeBetweenPorts(bottomLeftPort, bottomRightPort)
        eastWestEdgeFromTo(bottomLeft, topRight)
        setUpIds()
        return graph
    }

    func twoEdgesIntoSamePortFromEastWithFixedPortOrder() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let topLeft = addNodeToLayer(leftLayer)
        let bottomLeft = addNodeToLayer(leftLayer)
        let topRight = addNodeToLayer(rightLayer)
        let bottomRight = addNodeToLayer(rightLayer)
        setFixedOrderConstraint(bottomLeft)
        setFixedOrderConstraint(topRight)
        let topLeftPort = addPortOnSide(topLeft, .EAST)
        let bottomLeftPort = addPortOnSide(bottomLeft, .EAST)
        let topRightPort = addPortOnSide(topRight, .WEST)
        let bottomRightPort = addPortOnSide(bottomRight, .WEST)
        addEdgeBetweenPorts(bottomLeftPort, bottomRightPort)
        addEdgeBetweenPorts(bottomLeftPort, topRightPort)
        addEdgeBetweenPorts(topLeftPort, topRightPort)
        setUpIds()
        return graph
    }

    func multipleEdgesIntoOnePortAndFreePortOrder() -> LGraph {
        let layer = makeLayer()
        let nodes = addNodesToLayer(3, layer)
        let portOne = addPortOnSide(nodes[0], .WEST)
        let portTwo = addPortOnSide(nodes[1], .WEST)
        let portThree = addPortOnSide(nodes[2], .WEST)
        addEdgeBetweenPorts(portOne, portThree)
        addEdgeBetweenPorts(portTwo, portThree)
        return getGraph()
    }

    func getOnlyCorrectlyImprovedByBestOfForwardAndBackwardSweepsInSingleLayer() -> LGraph {
        let leftLayer = makeLayer()
        let rightLayer = makeLayer()
        let leftNode = addNodeToLayer(leftLayer)
        let rightNodes = addNodesToLayer(3, rightLayer)
        setFixedOrderConstraint(leftNode)
        addInLayerEdge(rightNodes[0], rightNodes[1], .WEST)
        eastWestEdgeFromTo(leftNode, rightNodes[2])
        eastWestEdgeFromTo(leftNode, rightNodes[2])
        return getGraph()
    }
}
