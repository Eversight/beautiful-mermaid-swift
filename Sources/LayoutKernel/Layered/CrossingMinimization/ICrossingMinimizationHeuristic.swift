// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/ICrossingMinimizationHeuristic.java

import Foundation

package protocol ICrossingMinimizationHeuristic: IInitializable {
    func alwaysImproves() -> Bool
    func setFirstLayerOrder(
        _ order: inout [[LNode]],
        _ forwardSweep: Bool
    ) -> Bool
    func minimizeCrossings(
        _ order: inout [[LNode]],
        _ freeLayerIndex: Int,
        _ forwardSweep: Bool,
        _ isFirstSweep: Bool
    ) -> Bool
    func isDeterministic() -> Bool
}
