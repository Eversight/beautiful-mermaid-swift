// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/SCConnectivity.java

import Foundation

package final class SCConnectivity: SCCModelOrderCycleBreaker {
    package override init() {
        super.init()
    }

    /// Java: SCConnectivity#findNodes(int offset, int bigOffset)
    package override func findNodes(_ offset: Int, _ bigOffset: Int) {
        guard let graph else {
            return
        }

        let enforceGroupModelOrder = ModelOrderPropertyScaffolding
            .groupOrderStrategy(for: graph) == .ENFORCED

        for component in stronglyConnectedComponents where component.count > 1 {
            let calculator = GroupModelOrderCalculator()
            let edges = Self.selectEdgesForStronglyConnectedComponent(component) { node in
                enforceGroupModelOrder
                    ? calculator.computeConstraintGroupModelOrder(node, bigOffset, offset)
                    : calculator.computeConstraintModelOrder(node, offset)
            }
            revEdges.append(contentsOf: edges)
        }
    }

    /// Faithful core selection logic from Java, extracted so it can be reused once SCC/runtime dependencies exist.
    package static func selectEdgesForStronglyConnectedComponent(
        _ component: [LNode],
        _ modelOrder: (LNode) -> Int
    ) -> [LEdge] {
        if component.count <= 1 {
            return []
        }

        var minNode: LNode?
        var maxNode: LNode?
        var modelOrderMin = Int.max
        var modelOrderMax = Int.min

        for node in component {
            let currentOrder = modelOrder(node)

            if minNode == nil || maxNode == nil {
                minNode = node
                maxNode = node
                modelOrderMin = currentOrder
                modelOrderMax = currentOrder
            } else {
                if modelOrderMin > currentOrder {
                    minNode = node
                    modelOrderMin = currentOrder
                }
                if modelOrderMax < currentOrder {
                    maxNode = node
                    modelOrderMax = currentOrder
                }
            }
        }

        guard let minNode, let maxNode else {
            return []
        }

        var reversed: [LEdge] = []
        if minNode.getIncomingEdges().count > maxNode.getOutgoingEdges().count {
            for edge in minNode.getIncomingEdges() {
                if let sourceNode = edge.getSource()?.getNode(), containsIdentity(sourceNode, in: component) {
                    reversed.append(edge)
                }
            }
        } else {
            for edge in maxNode.getOutgoingEdges() {
                if let targetNode = edge.getTarget()?.getNode(), containsIdentity(targetNode, in: component) {
                    reversed.append(edge)
                }
            }
        }
        return reversed
    }

    package static func containsIdentity(
        _ node: LNode,
        in component: [LNode]
    ) -> Bool {
        component.contains(where: { $0 === node })
    }
}
