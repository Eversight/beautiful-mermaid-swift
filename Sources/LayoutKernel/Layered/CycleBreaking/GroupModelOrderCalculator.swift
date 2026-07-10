// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/GroupModelOrderCalculator.java

import Foundation

package enum ModelOrderPropertyScaffolding {
    package enum Keys {
        static let layerConstraint = "LAYERING_LAYER_CONSTRAINT"
        static let modelOrder = "INTERNAL_MODEL_ORDER"
        static let cycleBreakingGroupId = "MODEL_ORDER_CYCLE_BREAKING_ID"
        static let groupOrderStrategy = "CONSIDER_MODEL_ORDER_GROUP_MODEL_ORDER_CB_GROUP_ORDER_STRATEGY"
        static let maxModelOrderNodes = "INTERNAL_MAX_MODEL_ORDER_NODES"
        static let cbNumModelOrderGroups = "INTERNAL_CB_NUM_MODEL_ORDER_GROUPS"
    }

    // These scaffolding maps have no writers in the current port; kept immutable
    // so a future regression cannot reintroduce a process-wide mutable singleton
    // that would race under concurrent renders. If real writers are ever needed,
    // move the state onto the owning LGraph/LNode instead of a static map.
    package static let layerConstraintByNode: [ObjectIdentifier: LayerConstraint] = [:]
    package static let modelOrderByNode: [ObjectIdentifier: Int] = [:]
    package static let cycleBreakingGroupIdByNode: [ObjectIdentifier: Int] = [:]
    package static let groupOrderStrategyByGraph: [ObjectIdentifier: GroupOrderStrategy] = [:]
    package static let maxModelOrderNodesByGraph: [ObjectIdentifier: Int] = [:]
    package static let cbNumModelOrderGroupsByGraph: [ObjectIdentifier: Int] = [:]

    package static func layerConstraint(
        for node: LNode
    ) -> LayerConstraint? {
        layerConstraintByNode[ObjectIdentifier(node)]
    }

    package static func modelOrder(for node: LNode) -> Int? {
        modelOrderByNode[ObjectIdentifier(node)]
    }

    package static func cycleBreakingGroupId(for node: LNode) -> Int? {
        cycleBreakingGroupIdByNode[ObjectIdentifier(node)]
    }

    package static func groupOrderStrategy(
        for graph: LGraph?
    ) -> GroupOrderStrategy? {
        guard let graph else {
            return nil
        }
        return groupOrderStrategyByGraph[ObjectIdentifier(graph)]
    }

    package static func maxModelOrderNodes(for graph: LGraph?) -> Int? {
        guard let graph else {
            return nil
        }
        return maxModelOrderNodesByGraph[ObjectIdentifier(graph)]
    }

    package static func cbNumModelOrderGroups(for graph: LGraph?) -> Int? {
        guard let graph else {
            return nil
        }
        return cbNumModelOrderGroupsByGraph[ObjectIdentifier(graph)]
    }
}

package final class GroupModelOrderCalculator {
    package var firstSeparateNodes = 0
    package var lastSeparateNodes = 0

    package init() {}

    package func computeConstraintModelOrder(
        _ node: LNode,
        _ offset: Int
    ) -> Int {
        var modelOrder = 0
        switch layerConstraint(for: node) {
        case .FIRST_SEPARATE:
            modelOrder = (2 * -offset) + firstSeparateNodes
            firstSeparateNodes += 1
        case .FIRST:
            modelOrder = -offset
        case .LAST:
            modelOrder = offset
        case .LAST_SEPARATE:
            modelOrder = (2 * offset) + lastSeparateNodes
            lastSeparateNodes += 1
        case .NONE:
            break
        }

        if let nodeModelOrder = modelOrderProperty(for: node) {
            modelOrder += nodeModelOrder
        }
        return modelOrder
    }

    package func computeConstraintGroupModelOrder(
        _ node: LNode,
        _ offset: Int,
        _ smallOffset: Int
    ) -> Int {
        var modelOrder = 0
        switch layerConstraint(for: node) {
        case .FIRST_SEPARATE:
            modelOrder = (2 * -offset) + firstSeparateNodes
            firstSeparateNodes += 1
        case .FIRST:
            modelOrder = -offset
        case .LAST:
            modelOrder = offset
        case .LAST_SEPARATE:
            modelOrder = (2 * offset) + lastSeparateNodes
            lastSeparateNodes += 1
        case .NONE:
            break
        }

        if let components = groupModelOrderComponents(for: node) {
            modelOrder += (components.groupId * smallOffset) + components.modelOrder
        }
        return modelOrder
    }

    package func resetInternalCounters() {
        firstSeparateNodes = 0
        lastSeparateNodes = 0
    }

    package func layerConstraint(
        for node: LNode
    ) -> LayerConstraint {
        ModelOrderPropertyScaffolding
            .layerConstraint(for: node) ?? .NONE
    }

    package func modelOrderProperty(for node: LNode) -> Int? {
        ModelOrderPropertyScaffolding
            .modelOrder(for: node) ?? node.id
    }

    package func groupModelOrderComponents(
        for node: LNode
    ) -> (groupId: Int, modelOrder: Int)? {
        guard let modelOrder = modelOrderProperty(for: node) else {
            return nil
        }
        let groupId = ModelOrderPropertyScaffolding
            .cycleBreakingGroupId(for: node) ?? 0
        return (groupId: groupId, modelOrder: modelOrder)
    }
}
