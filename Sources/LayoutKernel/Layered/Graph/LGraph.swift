import Foundation

/**
 * A layered graph has a set of layers that contain the nodes, as well as a
 * list of nodes that are not yet assigned to a layer.
 */
package final class LGraph: LGraphElement {

    package var size = KVector()
    package var padding = LPadding()
    package var offset = KVector()
    package var layerlessNodes = [LNode]()
    package var layers = [Layer]()
    package var parentNode: LNode?

    /// Every node ever associated with this graph, including dummies later
    /// removed from the layers. Swept by `tearDown()` — see `LNode.graph`.
    private var createdNodes = [LNode]()

    package func registerCreatedNode(_ node: LNode) {
        createdNodes.append(node)
    }

    package func getSize() -> KVector {
        return size
    }

    package func getActualSize() -> KVector {
        return KVector(
            size.x + padding.left + padding.right,
            size.y + padding.top + padding.bottom
        )
    }

    package func getPadding() -> LPadding {
        return padding
    }

    package func getOffset() -> KVector {
        return offset
    }

    package func getLayerlessNodes() -> [LNode] {
        return layerlessNodes
    }

    package func getLayers() -> [Layer] {
        return layers
    }

    package func getParentNode() -> LNode? {
        return parentNode
    }

    package func setParentNode(_ parentNode: LNode?) {
        self.parentNode = parentNode
    }

    /// Creates a new Layer, appends it to the layers list, and sets its graph reference.
    @discardableResult
    package func addLayer() -> Layer {
        let layer = Layer(self)
        layers.append(layer)
        return layer
    }

    /// Removes the given layer from this graph's layers list.
    package func removeLayer(_ layer: Layer) {
        layers.removeAll { $0 === layer }
    }

    /// Removes the given node from the layerless nodes list.
    package func removeLayerlessNode(_ node: LNode) {
        layerlessNodes.removeAll { $0 === node }
    }

    package func toNodeArray() -> [[LNode]] {
        return layers.map { $0.getNodes() }
    }

    package func toString() -> String {
        if layers.isEmpty {
            return "G-unlayered\(layerlessNodes)"
        } else if layerlessNodes.isEmpty {
            return "G-layered\(layers)"
        }
        return "G[layerless\(layerlessNodes), layers\(layers)]"
    }

    // MARK: - Teardown

    /// Breaks every reference cycle inside a laid-out graph so ARC can free it.
    ///
    /// The structure is cyclic by design: `LGraph ↔ Layer ↔ LNode`,
    /// `LPort ↔ LEdge`, `LNode ↔ nested LGraph`, plus property maps that hold
    /// other graph elements (e.g. barycenter associates). The Java original
    /// relies on a tracing GC; under ARC a laid-out graph leaks in its entirety
    /// unless the cycles are cut. The layout provider calls this after the
    /// computed geometry has been applied back to the GraphNode graph. After
    /// teardown only downward (tree) references remain.
    package func tearDown() {
        var graphs: [LGraph] = [self]
        var pending: [LNode] = []
        var seen = Set<ObjectIdentifier>()
        while true {
            if let graph = graphs.popLast() {
                graph.clearAllProperties()
                graph.parentNode = nil
                for layer in graph.layers {
                    layer.clearAllProperties()
                    LGraph.enqueue(layer.nodes, into: &pending, seen: &seen)
                    layer.nodes.removeAll()
                }
                graph.layers.removeAll()
                LGraph.enqueue(graph.layerlessNodes, into: &pending, seen: &seen)
                graph.layerlessNodes.removeAll()
                LGraph.enqueue(graph.createdNodes, into: &pending, seen: &seen)
                graph.createdNodes.removeAll()
            }
            guard let node = pending.popLast() else {
                if graphs.isEmpty { break }
                continue
            }
            LGraph.tearDownNode(node, graphs: &graphs, pending: &pending, seen: &seen)
        }
    }

    private static func enqueue(_ nodes: [LNode], into pending: inout [LNode], seen: inout Set<ObjectIdentifier>) {
        for node in nodes where seen.insert(ObjectIdentifier(node)).inserted {
            pending.append(node)
        }
    }

    private static func tearDownNode(
        _ node: LNode,
        graphs: inout [LGraph],
        pending: inout [LNode],
        seen: inout Set<ObjectIdentifier>
    ) {
        node.clearAllProperties()
        node.graph = nil
        node.layer = nil
        for label in node.labels {
            label.clearAllProperties()
        }
        for port in node.ports {
            port.clearAllProperties()
            for label in port.labels {
                label.clearAllProperties()
            }
            // Follow edges to nodes that are no longer in any layer (dummies
            // removed during post-processing). Their strong `owner` backrefs
            // would otherwise keep whole orphan clusters alive.
            for edge in port.incomingEdges {
                tearDownEdge(edge, pending: &pending, seen: &seen)
            }
            for edge in port.outgoingEdges {
                tearDownEdge(edge, pending: &pending, seen: &seen)
            }
            port.incomingEdges.removeAll()
            port.outgoingEdges.removeAll()
            port.owner = nil
        }
        if let nested = node.nestedGraph {
            graphs.append(nested)
            node.nestedGraph = nil
        }
    }

    private static func tearDownEdge(_ edge: LEdge, pending: inout [LNode], seen: inout Set<ObjectIdentifier>) {
        edge.clearAllProperties()
        for label in edge.labels {
            label.clearAllProperties()
        }
        for endpoint in [edge.source, edge.target] {
            if let owner = endpoint?.owner, seen.insert(ObjectIdentifier(owner)).inserted {
                pending.append(owner)
            }
        }
    }
}

// Java's LGraph implements Iterable<Layer>, so support for-in over layers.
extension LGraph: Sequence {
    package typealias Element = Layer
    package func makeIterator() -> IndexingIterator<[Layer]> {
        return layers.makeIterator()
    }
}
