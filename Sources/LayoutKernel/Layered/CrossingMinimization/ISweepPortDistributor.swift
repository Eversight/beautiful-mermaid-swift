// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/ISweepPortDistributor.java

import Foundation

package protocol ISweepPortDistributor: IInitializable {
    func distributePortsWhileSweeping(
        _ order: [[LNode]],
        _ freeLayerIndex: Int,
        _ isForwardSweep: Bool
    ) -> Bool
}

package extension ISweepPortDistributor {
    package static func create<R: RandomNumberGenerator>(
        _ cmt: CrossMinType,
        _ r: inout R,
        _ currentOrder: [[LNode]]
    ) -> any ISweepPortDistributor {
        if cmt == .TWO_SIDED_GREEDY_SWITCH {
            return GreedyPortDistributor()
        } else if Bool.random(using: &r) {
            return NodeRelativePortDistributor(currentOrder.count)
        } else {
            return LayerTotalPortDistributor(currentOrder.count)
        }
    }
}
