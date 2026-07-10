// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/LayerSweepCrossingMinimizer.java
import Foundation

package enum CrossMinType {
    case BARYCENTER
    case ONE_SIDED_GREEDY_SWITCH
    case TWO_SIDED_GREEDY_SWITCH
    case MEDIAN
}

package final class LayerSweepCrossingMinimizer:
    IHierarchyAwareLayoutProcessor
{
    package enum _Keys {
        static let hierarchyHandling = "org.eclipse.elk.hierarchyHandling"
        static let portConstraints = "org.eclipse.elk.portConstraints"
        static let firstTryWithInitialOrder = "org.eclipse.elk.layered.firstTryWithInitialOrder"
        static let secondTryWithInitialOrder = "org.eclipse.elk.layered.secondTryWithInitialOrder"
        static let considerModelOrderStrategy = "org.eclipse.elk.layered.considerModelOrder.strategy"
        static let considerModelOrderPortModelOrder =
            "org.eclipse.elk.layered.considerModelOrder.portModelOrder"
        static let thoroughness = "org.eclipse.elk.layered.thoroughness"
        static let modelOrderCounterNodeInfluence =
            "org.eclipse.elk.layered.considerModelOrder.crossingCounterNodeInfluence"
        static let modelOrderCounterPortInfluence =
            "org.eclipse.elk.layered.considerModelOrder.crossingCounterPortInfluence"
        static let cmGroupOrderStrategy =
            LayeredOptions.CONSIDER_MODEL_ORDER_GROUP_MODEL_ORDER_CM_GROUP_ORDER_STRATEGY
        static let origin = "org.eclipse.elk.layered.origin"
        static let portDummy = "org.eclipse.elk.layered.portDummy"
    }

    package static let INTERMEDIATE_PROCESSING_CONFIGURATION: LayoutProcessorConfiguration<LayeredPhases, LGraph> =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P3_NODE_ORDERING,
                IntermediateProcessorStrategy.LONG_EDGE_SPLITTER
            )
            .addBefore(
                LayeredPhases.P4_NODE_PLACEMENT,
                IntermediateProcessorStrategy.IN_LAYER_CONSTRAINT_PROCESSOR
            )
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.LONG_EDGE_JOINER
            )

    package var graphInfoHolders: [GraphInfoHolder] = []
    package var graphsWhoseNodeOrderChanged: Set<ObjectIdentifier> = []
    package var random: Random?
    package var randomSeed: Int = 0
    package var crossMinType: CrossMinType

    /// Parity-harness trace (see `SweepTrace`). Test-only; nil in production.
    package static var trace: SweepTrace?

    /// The flat sweep engine (S2') handles the common configuration; the
    /// object path remains for everything else and as an escape hatch
    /// (`BM_OBJECT_SWEEP=1` in the environment forces it, for A/B benches
    /// and regression triage). Mutable so the differential tests can pin
    /// one run to each engine; production code never writes it.
    package static var flatEngineEnabled =
        ProcessInfo.processInfo.environment["BM_OBJECT_SWEEP"] == nil

    package init() {
        crossMinType = .BARYCENTER
    }

    package init(_ cT: CrossMinType) {
        crossMinType = cT
    }

    package func process(
        _ layeredGraph: LGraph,
        _ progressMonitor: any IElkProgressMonitor
    ) {
        progressMonitor.begin("Minimize Crossings \(crossMinType)", 1)

        let emptyGraph = layeredGraph.getLayers().isEmpty
            || layeredGraph.getLayers().allSatisfy { $0.getNodes().isEmpty }
        let singleNode = layeredGraph.getLayers().count == 1
            && (layeredGraph.getLayers().first?.getNodes().count ?? 0) == 1
        let hierarchy = layeredGraph.getProperty(_Keys.hierarchyHandling) as? HierarchyHandling
            ?? .INHERIT
        let hierarchicalLayout = hierarchy == .INCLUDE_CHILDREN

        if emptyGraph || (singleNode && !hierarchicalLayout) {
            progressMonitor.done()
            return
        }

        let graphsToSweepOn = initialize(layeredGraph)

        // v1 flat-engine dispatch (docs/SweepEngineContract.md §1): plain
        // barycenter on a flat graph — the configuration every Mermaid
        // diagram uses. The object path serves everything else.
        if Self.flatEngineEnabled,
           let holder = graphsToSweepOn.first,
           shouldUseFlatEngine(holder, layeredGraph)
        {
            var engine = SweepEngine(
                graph: SweepGraph(nodeOrder: holder.currentNodeOrder()),
                random: random
            )
            engine.useNodeRelativeRanks = holder.portDistributor() is NodeRelativePortDistributor
            let thoroughness = Self._intProperty(layeredGraph, _Keys.thoroughness) ?? 7
            let strategy = layeredGraph.getProperty(_Keys.considerModelOrderStrategy)
                as? OrderingStrategy ?? .NONE
            engine.compareDifferentRandomizedLayouts(
                holder: holder, randomSeed: randomSeed, thoroughness: thoroughness,
                modelOrderStrategyActive: strategy != .NONE
            )
            engine.transferBestOrders(to: layeredGraph)
            progressMonitor.done()
            return
        }

        let minimizingMethod = chooseMinimizingMethod(graphsToSweepOn)
        minimizeCrossings(graphsToSweepOn, minimizingMethod)
        transferNodeAndPortOrdersToGraph()

        progressMonitor.done()
    }

    /// The v1 subset the flat engine reproduces byte-for-byte: single flat
    /// graph, plain BarycenterHeuristic, no model-order machinery.
    package func shouldUseFlatEngine(_ holder: GraphInfoHolder, _ graph: LGraph) -> Bool {
        guard crossMinType == .BARYCENTER,
              graphInfoHolders.count == 1,
              !holder.hasParent(),
              holder.childGraphs().isEmpty,
              !holder.hasExternalPorts(),
              !holder.currentNodeOrder().isEmpty,
              holder.crossMinimizer() is BarycenterHeuristic
        else {
            return false
        }
        // ModelOrderBarycenterHeuristic is a BarycenterHeuristic subclass but
        // overrides the sort entirely — excluded by exact-type check.
        guard type(of: holder.crossMinimizer()) == BarycenterHeuristic.self else {
            return false
        }
        // Any modelOrder STRATEGY is covered (the firstTry/secondTry rotation
        // is mirrored); nonzero counter INFLUENCES switch the driver to the
        // Double-valued fitness loop, which is not.
        let nodeInfluence = graph.getProperty(_Keys.modelOrderCounterNodeInfluence) as? Double ?? 0
        let portInfluence = graph.getProperty(_Keys.modelOrderCounterPortInfluence) as? Double ?? 0
        return nodeInfluence == 0 && portInfluence == 0
    }

    package func chooseMinimizingMethod(
        _ graphsToSweepOn: [GraphInfoHolder]
    ) -> (GraphInfoHolder) -> Void {
        guard let parent = graphsToSweepOn.first else {
            return { _ in }
        }

        if !parent.crossMinDeterministic() {
            return compareDifferentRandomizedLayouts
        }
        if parent.crossMinAlwaysImproves() {
            return minimizeCrossingsNoCounter
        }
        return { [weak self] g in
            _ = self?.minimizeCrossingsWithCounter(g)
        }
    }

    package func minimizeCrossings(
        _ graphsToSweepOn: [GraphInfoHolder],
        _ minimizingMethod: (GraphInfoHolder) -> Void
    ) {
        for gData in graphsToSweepOn {
            if !gData.currentNodeOrder().isEmpty {
                minimizingMethod(gData)
                if gData.hasParent() {
                    setPortOrderOnParentGraph(gData)
                }
            }
        }
    }

    package func setPortOrderOnParentGraph(_ gData: GraphInfoHolder) {
        guard gData.hasExternalPorts(),
              let bestSweep = gData.getBestSweep(),
              let bestNodes = bestSweep.nodes()
        else {
            return
        }

        sortPortsByDummyPositionsInLastLayer(bestNodes, gData.parent(), true)
        sortPortsByDummyPositionsInLastLayer(bestNodes, gData.parent(), false)
        gData.parent().setProperty(_Keys.portConstraints, PortConstraints.FIXED_ORDER)
    }

    package func minimizeCrossingsNoCounter(_ gData: GraphInfoHolder) {
        var isForwardSweep = nextRandomBool()
        Self.trace?.record(.tryStart(forward: isForwardSweep))
        var improved = true

        while improved {
            improved = false
            improved = setFirstLayerOrder(gData, isForwardSweep)
            improved = sweepReducingCrossings(gData, isForwardSweep, false) || improved
            isForwardSweep.toggle()
        }

        setCurrentlyBestNodeOrders()
    }

    package func compareDifferentRandomizedLayouts(_ gData: GraphInfoHolder) {
        // Reset the seed, otherwise copies of hierarchical graphs in different parent nodes
        // are laid out differently. Matches Java: random.setSeed(randomSeed)
        random?.setSeed(randomSeed)
        graphsWhoseNodeOrderChanged.removeAll(keepingCapacity: true)

        let nodeInfluence = gData.lGraph().getProperty(_Keys.modelOrderCounterNodeInfluence) as? Double ?? 0
        let portInfluence = gData.lGraph().getProperty(_Keys.modelOrderCounterPortInfluence) as? Double ?? 0
        let strategy = gData.lGraph().getProperty(_Keys.considerModelOrderStrategy)
            as? OrderingStrategy ?? .NONE

        if nodeInfluence != 0 || portInfluence != 0 {
            var bestCrossings = Double.greatestFiniteMagnitude
            if strategy != .NONE {
                gData.lGraph().setProperty(_Keys.firstTryWithInitialOrder, true)
            }
            let thoroughness = Self._intProperty(gData.lGraph(), _Keys.thoroughness) ?? 7
            for _ in 0..<max(1, thoroughness) {
                let crossings = minimizeCrossingsNodePortOrderWithCounter(gData)
                if crossings < bestCrossings {
                    bestCrossings = crossings
                    saveAllNodeOrdersOfChangedGraphs()
                    if bestCrossings == 0 {
                        break
                    }
                }
            }
        } else {
            var bestCrossings = Int.max
            if strategy != .NONE {
                gData.lGraph().setProperty(_Keys.firstTryWithInitialOrder, true)
            }
            let thoroughness = Self._intProperty(gData.lGraph(), _Keys.thoroughness) ?? 7
            for _ in 0..<max(1, thoroughness) {
                let crossings = minimizeCrossingsWithCounter(gData)
                if crossings < bestCrossings {
                    bestCrossings = crossings
                    saveAllNodeOrdersOfChangedGraphs()
                    if bestCrossings == 0 {
                        break
                    }
                }
            }
        }
    }

    package func minimizeCrossingsWithCounter(_ gData: GraphInfoHolder) -> Int {
        var isForwardSweep = nextRandomBool()
        Self.trace?.record(.tryStart(forward: isForwardSweep))
        let initialCrossings = countCurrentNumberOfCrossings(gData)
        Self.trace?.record(.count(crossings: initialCrossings))
        let _firstTry = gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false
        let _secondTry = gData.lGraph().getProperty(_Keys.secondTryWithInitialOrder) as? Bool ?? false


        if initialCrossings == 0, _firstTry {
            return 0
        }

        let considerModelOrder = gData.lGraph().getProperty(_Keys.considerModelOrderStrategy)
            as? OrderingStrategy ?? .NONE

        if (!(_firstTry || _secondTry)) || considerModelOrder == .NONE {
            _ = setFirstLayerOrder(gData, isForwardSweep)
        } else {
            isForwardSweep = _firstTry
        }

        _ = sweepReducingCrossings(gData, isForwardSweep, true)

        if gData.lGraph().getProperty(_Keys.secondTryWithInitialOrder) as? Bool ?? false {
            gData.lGraph().setProperty(_Keys.secondTryWithInitialOrder, false)
        }
        if gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false {
            gData.lGraph().setProperty(_Keys.firstTryWithInitialOrder, false)
            gData.lGraph().setProperty(_Keys.secondTryWithInitialOrder, true)
        }

        var crossingsInGraph = countCurrentNumberOfCrossings(gData)
        Self.trace?.record(.count(crossings: crossingsInGraph))
        var oldCrossings: Int
        var sweepIter = 0
        repeat {
            setCurrentlyBestNodeOrders()
            if crossingsInGraph == 0 {
                return 0
            }
            isForwardSweep.toggle()
            oldCrossings = crossingsInGraph
            _ = sweepReducingCrossings(gData, isForwardSweep, false)
            crossingsInGraph = countCurrentNumberOfCrossings(gData)
            Self.trace?.record(.count(crossings: crossingsInGraph))
            sweepIter += 1
        } while oldCrossings > crossingsInGraph

        return oldCrossings
    }

    package func minimizeCrossingsNodePortOrderWithCounter(
        _ gData: GraphInfoHolder
    ) -> Double {
        var isForwardSweep = nextRandomBool()
        let initialCrossings = countCurrentNumberOfCrossingsNodePortOrder(gData)

        if initialCrossings == 0,
           gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false
        {
            return 0
        }

        let considerModelOrder = gData.lGraph().getProperty(_Keys.considerModelOrderStrategy)
            as? OrderingStrategy ?? .NONE
        if (!((gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false)
            || (gData.lGraph().getProperty(_Keys.secondTryWithInitialOrder) as? Bool ?? false)))
            || considerModelOrder == .NONE
        {
            _ = setFirstLayerOrder(gData, isForwardSweep)
        } else {
            isForwardSweep = gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false
        }

        _ = sweepReducingCrossings(gData, isForwardSweep, true)
        if gData.lGraph().getProperty(_Keys.secondTryWithInitialOrder) as? Bool ?? false {
            gData.lGraph().setProperty(_Keys.secondTryWithInitialOrder, false)
        }
        if gData.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false {
            gData.lGraph().setProperty(_Keys.firstTryWithInitialOrder, false)
            gData.lGraph().setProperty(_Keys.secondTryWithInitialOrder, true)
        }

        var crossingsInGraph = countCurrentNumberOfCrossingsNodePortOrder(gData)
        var oldCrossings: Double
        repeat {
            setCurrentlyBestNodeOrders()
            if crossingsInGraph == 0 {
                return 0
            }
            isForwardSweep.toggle()
            oldCrossings = crossingsInGraph
            _ = sweepReducingCrossings(gData, isForwardSweep, false)
            crossingsInGraph = countCurrentNumberOfCrossingsNodePortOrder(gData)
        } while oldCrossings > crossingsInGraph

        return oldCrossings
    }

    package func countModelOrderNodeChanges(
        _ graph: LGraph,
        _ layers: [[LNode]],
        _ strategy: OrderingStrategy,
        _ cmGroupOrderStrategy: GroupOrderStrategy
    ) -> Int {
        var previousLayerIndex = -1
        var wrongModelOrder = 0

        for layer in layers {
            let previousLayer = previousLayerIndex == -1 ? layers[0] : layers[previousLayerIndex]
            let comp = ModelOrderNodeComparator(
                graph,
                previousLayer,
                strategy,
                .EQUAL,
                cmGroupOrderStrategy,
                false
            )
            if layer.count > 1 {
                for i in 0..<(layer.count - 1) {
                    for j in (i + 1)..<layer.count {
                        if layer[i].hasProperty(InternalProperties.MODEL_ORDER),
                           layer[j].hasProperty(InternalProperties.MODEL_ORDER),
                           comp.compare(layer[i], layer[j]) > 0
                        {
                            wrongModelOrder += 1
                        }
                    }
                }
            }
            previousLayerIndex += 1
        }
        return wrongModelOrder
    }

    package func countModelOrderPortChanges(
        _ graph: LGraph,
        _ layers: [[LNode]],
        _ groupOrderStrategy: GroupOrderStrategy
    ) -> Int {
        _ = groupOrderStrategy
        var previousLayerIndex = -1
        var wrongModelOrder = 0

        for layer in layers {
            let previousLayer = previousLayerIndex == -1 ? layers[0] : layers[previousLayerIndex]
            for node in layer {
                let comp = ModelOrderPortComparator(
                    graph,
                    previousLayer,
                    node.getGraph()?.getProperty(_Keys.considerModelOrderStrategy)
                        as? OrderingStrategy ?? .NODES_AND_EDGES,
                    SortByInputModelProcessor.longEdgeTargetNodePreprocessing(node),
                    node.getGraph()?.getProperty(_Keys.considerModelOrderPortModelOrder) as? Bool ?? false
                )
                let ports = node.getPorts()
                if ports.count > 1 {
                    for i in 0..<(ports.count - 1) {
                        for j in (i + 1)..<ports.count {
                            if comp.compare(ports[i], ports[j]) > 0 {
                                wrongModelOrder += 1
                            }
                        }
                    }
                }
            }
            previousLayerIndex += 1
        }
        return wrongModelOrder
    }

    package func countCurrentNumberOfCrossings(_ currentGraph: GraphInfoHolder) -> Int {
        let ownCrossings = currentGraph.crossCounter().countAllCrossings(currentGraph.currentNodeOrder())
        var childCrossings = 0
        for childGraph in currentGraph.childGraphs() {
            guard let child = graphData(for: childGraph), !child.dontSweepInto() else {
                continue
            }
            childCrossings += countCurrentNumberOfCrossings(child)
        }
        let totalCrossings = ownCrossings + childCrossings
        return totalCrossings
    }

    package func countCurrentNumberOfCrossingsNodePortOrder(
        _ currentGraph: GraphInfoHolder
    ) -> Double {
        var modelOrderInfluence = 0.0
        let modelOrderStrategy = currentGraph.lGraph().getProperty(_Keys.considerModelOrderStrategy)
            as? OrderingStrategy ?? .NONE
        let cmGroupOrderStrategy = currentGraph.lGraph().getProperty(_Keys.cmGroupOrderStrategy)
            as? GroupOrderStrategy ?? .ONLY_WITHIN_GROUP
        let nodeInfluence = currentGraph.lGraph().getProperty(_Keys.modelOrderCounterNodeInfluence) as? Double ?? 0
        let portInfluence = currentGraph.lGraph().getProperty(_Keys.modelOrderCounterPortInfluence) as? Double ?? 0

        if modelOrderStrategy != .NONE {
            modelOrderInfluence += nodeInfluence * Double(
                countModelOrderNodeChanges(
                    currentGraph.lGraph(),
                    currentGraph.currentNodeOrder(),
                    modelOrderStrategy,
                    cmGroupOrderStrategy
                )
            )
            modelOrderInfluence += portInfluence * Double(
                countModelOrderPortChanges(
                    currentGraph.lGraph(),
                    currentGraph.currentNodeOrder(),
                    cmGroupOrderStrategy
                )
            )
        }

        var totalCrossings = Double(currentGraph.crossCounter().countAllCrossings(currentGraph.currentNodeOrder()))
            + modelOrderInfluence
        for childGraph in currentGraph.childGraphs() {
            guard let child = graphData(for: childGraph), !child.dontSweepInto() else {
                continue
            }
            totalCrossings += Double(countCurrentNumberOfCrossings(child))
        }
        return totalCrossings
    }

    package func sweepReducingCrossings(
        _ graph: GraphInfoHolder,
        _ forward: Bool,
        _ firstSweep: Bool
    ) -> Bool {
        let nodes = graph.currentNodeOrder()
        let length = nodes.count
        if length == 0 {
            return false
        }

        var improved = graph.portDistributor().distributePortsWhileSweeping(nodes, firstIndex(forward, length), forward)
        let firstLayer = nodes[firstIndex(forward, length)]
        improved = sweepInHierarchicalNodes(firstLayer, forward, firstSweep) || improved

        var i = firstFree(forward, length)
        while isNotEnd(length, i, forward) {
            let isRandomizingSweep = firstSweep
                && !(graph.lGraph().getProperty(_Keys.firstTryWithInitialOrder) as? Bool ?? false)
                && !(graph.lGraph().getProperty(_Keys.secondTryWithInitialOrder) as? Bool ?? false)
            improved = crossMinimize(graph, i, forward, isRandomizingSweep) || improved
            improved = graph.portDistributor().distributePortsWhileSweeping(graph.currentNodeOrder(), i, forward)
                || improved
            let currentNodes = graph.currentNodeOrder()
            if i >= 0, i < currentNodes.count {
                improved = sweepInHierarchicalNodes(currentNodes[i], forward, firstSweep) || improved
            }
            i += next(forward)
        }

        graphsWhoseNodeOrderChanged.insert(ObjectIdentifier(graph))
        return improved
    }

    package func sweepInHierarchicalNodes(
        _ layer: [LNode],
        _ isForwardSweep: Bool,
        _ isFirstSweep: Bool
    ) -> Bool {
        var improved = false
        for node in layer where hasNestedGraph(node) {
            guard let nested = node.getNestedGraph(),
                  let nestedData = graphData(for: nested),
                  !nestedData.dontSweepInto()
            else {
                continue
            }
            improved = sweepInHierarchicalNode(isForwardSweep, node, isFirstSweep) || improved
        }
        return improved
    }

    package func sweepInHierarchicalNode(
        _ isForwardSweep: Bool,
        _ node: LNode,
        _ isFirstSweep: Bool
    ) -> Bool {
        guard let nestedLGraph = node.getNestedGraph(),
              let nestedGraph = graphData(for: nestedLGraph)
        else {
            return false
        }
        let nestedGraphNodeOrder = nestedGraph.currentNodeOrder()
        guard !nestedGraphNodeOrder.isEmpty else {
            return false
        }

        let startIndex = firstIndex(isForwardSweep, nestedGraphNodeOrder.count)
        guard !nestedGraphNodeOrder[startIndex].isEmpty else {
            return false
        }
        let firstNode = nestedGraphNodeOrder[startIndex][0]

        if isExternalPortDummy(firstNode) {
            var updated = nestedGraphNodeOrder
            updated[startIndex] = sortPortDummiesByPortPositions(
                node,
                updated[startIndex],
                sideOpposedSweepDirection(isForwardSweep)
            )
            nestedGraph.setCurrentNodeOrder(updated)
        } else {
            _ = setFirstLayerOrder(nestedGraph, isForwardSweep)
        }

        let improved = sweepReducingCrossings(nestedGraph, isForwardSweep, isFirstSweep)
        sortPortsByDummyPositionsInLastLayer(nestedGraph.currentNodeOrder(), nestedGraph.parent(), isForwardSweep)

        return improved
    }

    package func sortPortsByDummyPositionsInLastLayer(
        _ nodeOrder: [[LNode]],
        _ parent: LNode,
        _ onRightMostLayer: Bool
    ) {
        guard !nodeOrder.isEmpty else {
            return
        }
        let lastLayerIndex = endIndex(onRightMostLayer, nodeOrder.count)
        let lastLayer = nodeOrder[lastLayerIndex]
        guard !lastLayer.isEmpty else {
            return
        }

        var dummyIndex = firstIndex(onRightMostLayer, lastLayer.count)
        guard isExternalPortDummy(lastLayer[dummyIndex]) else {
            return
        }

        var reordered = parent.getPorts()
        for i in reordered.indices {
            let port = reordered[i]
            if isOnEndOfSweepSide(port, onRightMostLayer),
               isHierarchical(port),
               dummyIndex >= 0,
               dummyIndex < lastLayer.count,
               let origin = originPort(lastLayer[dummyIndex])
            {
                reordered[i] = origin
                dummyIndex += next(onRightMostLayer)
            }
        }
        parent.ports = reordered
    }

    package func sortPortDummiesByPortPositions(
        _ parentNode: LNode,
        _ layerCloseToNodeEdge: [LNode],
        _ side: PortSide
    ) -> [LNode] {
        let ports = orderedPorts(parentNode, side)
        var sortedDummies: [LNode] = []
        sortedDummies.reserveCapacity(layerCloseToNodeEdge.count)

        for port in ports where isHierarchical(port) {
            if let dummy = dummyNodeFor(port) {
                sortedDummies.append(dummy)
            }
        }

        return Array(sortedDummies.prefix(layerCloseToNodeEdge.count))
    }

    package func saveAllNodeOrdersOfChangedGraphs() {
        Self.trace?.record(.saveBest)
        for graph in graphInfoHolders where graphsWhoseNodeOrderChanged.contains(ObjectIdentifier(graph)) {
            graph.setBestNodeNPortOrder(
                SweepCopy(
                    graph.currentlyBestNodeAndPortOrder()
                        ?? SweepCopy(graph.currentNodeOrder())
                )
            )
        }
    }

    package func setCurrentlyBestNodeOrders() {
        Self.trace?.record(.snapshotBest)
        for graph in graphInfoHolders where graphsWhoseNodeOrderChanged.contains(ObjectIdentifier(graph)) {
            graph.setCurrentlyBestNodeAndPortOrder(
                SweepCopy(graph.currentNodeOrder())
            )
        }
    }

    package func firstIndex(_ isForwardSweep: Bool, _ length: Int) -> Int {
        isForwardSweep ? 0 : (length - 1)
    }

    package func endIndex(_ isForwardSweep: Bool, _ length: Int) -> Int {
        isForwardSweep ? (length - 1) : 0
    }

    package func firstFree(_ isForwardSweep: Bool, _ length: Int) -> Int {
        isForwardSweep ? 1 : (length - 2)
    }

    package func next(_ isForwardSweep: Bool) -> Int {
        isForwardSweep ? 1 : -1
    }

    package func isNotEnd(_ length: Int, _ freeLayerIndex: Int, _ isForwardSweep: Bool) -> Bool {
        if isForwardSweep {
            return freeLayerIndex < length
        }
        return freeLayerIndex >= 0
    }

    package func hasNestedGraph(_ node: LNode) -> Bool {
        node.getNestedGraph() != nil
    }

    package func sideOpposedSweepDirection(_ isForwardSweep: Bool) -> PortSide {
        isForwardSweep ? .WEST : .EAST
    }

    package func isExternalPortDummy(_ firstNode: LNode) -> Bool {
        firstNode.getType() == .EXTERNAL_PORT
    }

    package func originPort(_ node: LNode) -> LPort? {
        node.getProperty(_Keys.origin) as? LPort
    }

    package func isHierarchical(_ port: LPort) -> Bool {
        port.getProperty(InternalProperties.INSIDE_CONNECTIONS) as? Bool ?? false
    }

    package func dummyNodeFor(_ port: LPort) -> LNode? {
        port.getProperty(InternalProperties.PORT_DUMMY) as? LNode
    }

    package func isOnEndOfSweepSide(
        _ port: LPort,
        _ isForwardSweep: Bool
    ) -> Bool {
        if isForwardSweep {
            return port.getSide() == .EAST
        }
        return port.getSide() == .WEST
    }

    package func initialize(
        _ rootGraph: LGraph
    ) -> [GraphInfoHolder] {
        graphInfoHolders = []
        random = rootGraph.getProperty(InternalProperties.RANDOM) as? Random
        randomSeed = Int(random?.nextLong() ?? 0)

        var graphsToSweepOn: [GraphInfoHolder] = []
        var graphs: [LGraph] = [rootGraph]

        var i = 0
        while i < graphs.count {
            let graph = graphs[i]
            graph.id = i
            i += 1

            let graphData = GraphInfoHolder(
                graph,
                mapCrossMinType(crossMinType),
                graphInfoHolders,
                crossMinType
            )
            graphs.append(contentsOf: graphData.childGraphs())
            graphInfoHolders.append(graphData)
            let sweep = graphData.dontSweepInto()
            if sweep {
                graphsToSweepOn.insert(graphData, at: 0)
            }
        }

        graphsWhoseNodeOrderChanged.removeAll(keepingCapacity: true)
        return graphsToSweepOn
    }

    package func transferNodeAndPortOrdersToGraph() {
        for holder in graphInfoHolders {
            if let bestSweep = holder.getBestSweep() {
                bestSweep.transferNodeAndPortOrdersToGraph(holder.lGraph(), true)
            }
        }
    }

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        _ = graph
        let configuration = LayoutProcessorConfiguration<LayeredPhases, LGraph>.create(
            from: Self.INTERMEDIATE_PROCESSING_CONFIGURATION
        )
        configuration.addBefore(
            LayeredPhases.P3_NODE_ORDERING,
            IntermediateProcessorStrategy.PORT_LIST_SORTER
        )
        return configuration
    }

    package func getGraphData() -> [GraphInfoHolder] {
        graphInfoHolders
    }

    package func graphData(for graph: LGraph)
        -> GraphInfoHolder?
    {
        let graphId = graph.id
        guard graphId >= 0, graphId < graphInfoHolders.count else {
            return nil
        }
        return graphInfoHolders[graphId]
    }

    package func mapCrossMinType(
        _ value: CrossMinType
    ) -> CrossMinStrategy {
        switch value {
        case .BARYCENTER:
            return .BARYCENTER
        case .MEDIAN:
            return .MEDIAN
        case .ONE_SIDED_GREEDY_SWITCH, .TWO_SIDED_GREEDY_SWITCH:
            return .GREEDY_SWITCH
        }
    }

    package func setFirstLayerOrder(
        _ graph: GraphInfoHolder,
        _ forward: Bool
    ) -> Bool {
        var order = graph.currentNodeOrder()
        let improved = graph.crossMinimizer().setFirstLayerOrder(&order, forward)
        graph.setCurrentNodeOrder(order)
        if let trace = Self.trace, !order.isEmpty {
            let index = firstIndex(forward, order.count)
            trace.record(.layerOrder(layer: index, nodeIds: order[index].map(\.id)))
        }
        return improved
    }

    package func crossMinimize(
        _ graph: GraphInfoHolder,
        _ index: Int,
        _ forward: Bool,
        _ randomize: Bool
    ) -> Bool {
        var order = graph.currentNodeOrder()
        let improved = graph.crossMinimizer().minimizeCrossings(&order, index, forward, randomize)
        graph.setCurrentNodeOrder(order)
        if let trace = Self.trace, index >= 0, index < order.count {
            trace.record(.layerOrder(layer: index, nodeIds: order[index].map(\.id)))
        }
        return improved
    }

    package func orderedPorts(
        _ node: LNode,
        _ side: PortSide
    ) -> [LPort] {
        switch side {
        case .EAST, .NORTH:
            return Array(node.getPortSideView(side))
        case .SOUTH, .WEST:
            return Array(node.getPortSideView(side).reversed())
        case .UNDEFINED:
            return []
        }
    }

    package func nextRandomBool() -> Bool {
        return random?.nextBoolean() ?? true
    }

    /// Read an Int property that might be stored as Double (from JSON parsing).
    private static func _intProperty(_ graph: LGraph, _ key: String) -> Int? {
        if let i = graph.getProperty(key) as? Int { return i }
        if let d = graph.getProperty(key) as? Double { return Int(d) }
        return nil
    }
}
