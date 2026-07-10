// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/GreedyModelOrderCycleBreaker.java

import Foundation

package final class GreedyModelOrderCycleBreaker: GreedyCycleBreaker {
    package override init() {
        super.init()
    }

    package override func chooseNodeWithMaxOutflow(
        _ nodes: [LNode]
    ) -> LNode {
        guard !nodes.isEmpty else {
            assertionFailure("chooseNodeWithMaxOutflow called with empty nodes")
            return LNode(LGraph())
        }

        var returnNode: LNode?
        var minimumModelOrder = Int.max

        let graph = nodes.first?.getGraph()
        let maxModelOrderNodes =
            ModelOrderPropertyScaffolding
                .maxModelOrderNodes(for: graph) ?? 1
        let cbNumModelOrderGroups =
            ModelOrderPropertyScaffolding
                .cbNumModelOrderGroups(for: graph) ?? 1
        let offset = max(nodes.count, maxModelOrderNodes)
        let bigOffset = offset * max(cbNumModelOrderGroups, 1)

        let moCalculator = GroupModelOrderCalculator()
        let enforceGroupModelOrder = shouldEnforceGroupModelOrder(graph)

        for node in nodes {
            let modelOrder = enforceGroupModelOrder
                ? moCalculator.computeConstraintGroupModelOrder(node, bigOffset, offset)
                : moCalculator.computeConstraintModelOrder(node, offset)

            if minimumModelOrder > modelOrder {
                minimumModelOrder = modelOrder
                returnNode = node
            }
        }

        return returnNode ?? nodes[0]
    }

    package func shouldEnforceGroupModelOrder(
        _ graph: LGraph?
    ) -> Bool {
        ModelOrderPropertyScaffolding
            .groupOrderStrategy(for: graph) == .ENFORCED
    }
}
