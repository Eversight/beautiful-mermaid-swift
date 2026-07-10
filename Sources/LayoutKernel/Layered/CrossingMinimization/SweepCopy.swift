// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/SweepCopy.java

import Foundation

package final class SweepCopy {
    package static let PORT_CONSTRAINTS_KEY: any IProperty = Property<PortConstraints>("org.eclipse.elk.portConstraints")
    package static let INTERNAL_IN_LAYER_LAYOUT_UNIT_KEY = InternalProperties.IN_LAYER_LAYOUT_UNIT
    package static let INTERNAL_ORIGIN_KEY = InternalProperties.ORIGIN

    // Java: LNode[][]
    package let nodeOrder: [[LNode]]?
    // Java: List<List<List<LPort>>>
    package let portOrders: [[[LPort]]]

    package init(_ nodeOrderIn: [[LNode]]?) {
        nodeOrder = Self.deepCopy(nodeOrderIn)
        var newPortOrders: [[[LPort]]] = []
        if let nodeOrderIn {
            newPortOrders.reserveCapacity(nodeOrderIn.count)
            for layerNodes in nodeOrderIn {
                var layerPorts: [[LPort]] = []
                layerPorts.reserveCapacity(layerNodes.count)
                for node in layerNodes {
                    layerPorts.append(node.getPorts())
                }
                newPortOrders.append(layerPorts)
            }
        }
        portOrders = newPortOrders
    }

    package init(_ sc: SweepCopy) {
        nodeOrder = Self.deepCopy(sc.nodeOrder)
        // Java copies only outer list here; Swift arrays remain CoW and keep shared element identity.
        portOrders = sc.portOrders
    }

    package static func deepCopy(
        _ currentBestNodeOrder: [[LNode]]?
    ) -> [[LNode]]? {
        guard let currentBestNodeOrder else {
            return nil
        }
        var result: [[LNode]] = []
        result.reserveCapacity(currentBestNodeOrder.count)
        for layer in currentBestNodeOrder {
            result.append(layer)
        }
        return result
    }

    package func nodes() -> [[LNode]]? {
        nodeOrder
    }

    package func transferNodeAndPortOrdersToGraph(
        _ lGraph: LGraph,
        _ setPortContstraints: Bool
    ) {
        guard let nodeOrder else {
            return
        }

        var updatePortOrder: [ObjectIdentifier: LNode] = [:]
        let layers = lGraph.getLayers()
        let layerLimit = min(layers.count, nodeOrder.count)

        for i in 0..<layerLimit {
            let layer = layers[i]
            var graphLayerNodes = layer.getNodes()
            let orderedLayerNodes = nodeOrder[i]
            var northSouthPortDummies: [LNode] = []

            let nodeLimit = min(graphLayerNodes.count, orderedLayerNodes.count)
            for j in 0..<nodeLimit {
                let node = orderedLayerNodes[j]
                node.id = j
                if node.getType() == .NORTH_SOUTH_PORT {
                    northSouthPortDummies.append(node)
                }

                graphLayerNodes[j] = node

                if i < portOrders.count, j < portOrders[i].count {
                    applyPortOrder(portOrders[i][j], to: node)
                }

                if setPortContstraints {
                    let existing = node.getProperty(Self.PORT_CONSTRAINTS_KEY)
                        as? PortConstraints
                    let constraints = existing ?? .UNDEFINED
                    if !constraints.isOrderFixed() {
                        node.setProperty(Self.PORT_CONSTRAINTS_KEY, PortConstraints.FIXED_ORDER)
                    }
                }
            }

            layer.setNodes(graphLayerNodes)

            for dummy in northSouthPortDummies {
                if let origin = assertCorrectPortSides(dummy) {
                    updatePortOrder[ObjectIdentifier(origin)] = origin
                    updatePortOrder[ObjectIdentifier(dummy)] = dummy
                }
            }
        }

        for node in updatePortOrder.values {
            let sorted = node.getPorts().enumerated().sorted { lhs, rhs in
                let cmp = PortListSorter.CMP_COMBINED(
                    lhs.element,
                    rhs.element
                )
                if cmp != 0 {
                    return cmp < 0
                }
                // Keep Java's stable-sort behavior for equal comparator values.
                return lhs.offset < rhs.offset
            }.map(\.element)
            applyPortOrder(sorted, to: node)
            node.cachePortSides()
        }
    }

    package func assertCorrectPortSides(
        _ dummy: LNode
    ) -> LNode? {
        guard dummy.getType() == .NORTH_SOUTH_PORT else {
            return nil
        }

        guard let origin: LNode = dummy.getProperty(Self.INTERNAL_IN_LAYER_LAYOUT_UNIT_KEY) else {
            return nil
        }

        let dummyPorts = dummy.getPorts()
        guard let dummyPort = dummyPorts.first else {
            return origin
        }

        let representedPort: LPort? = dummyPort.getProperty(Self.INTERNAL_ORIGIN_KEY)
        guard let representedPort else {
            return origin
        }

        for port in origin.getPorts() where port === representedPort {
            if port.getSide() == .NORTH && dummy.id > origin.id {
                port.setSide(.SOUTH)
                if port.isExplicitlySuppliedPortAnchor() {
                    let portHeight = port.getSize().y
                    let anchorY = port.getAnchor().y
                    port.getAnchor().y = portHeight - anchorY
                }
            } else if port.getSide() == .SOUTH && origin.id > dummy.id {
                port.setSide(.NORTH)
                if port.isExplicitlySuppliedPortAnchor() {
                    let portHeight = port.getSize().y
                    let anchorY = port.getAnchor().y
                    port.getAnchor().y = -(portHeight - anchorY)
                }
            }
            break
        }

        return origin
    }

    package func applyPortOrder(
        _ orderedPorts: [LPort],
        to node: LNode
    ) {
        for port in node.getPorts() {
            port.setNode(nil)
        }
        for port in orderedPorts {
            port.setNode(node)
        }
    }
}
