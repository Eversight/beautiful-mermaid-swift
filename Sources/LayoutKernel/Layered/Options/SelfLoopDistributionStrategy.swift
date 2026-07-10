// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/SelfLoopDistributionStrategy.java

import Foundation

package enum SelfLoopDistributionStrategy {
    /// Distributes the loops equally around the node.
    case EQUALLY
    /// Puts all loops to the north side of the node.
    case NORTH
    /// Loops are distributed over the north and the south side of the node.
    case NORTH_SOUTH
}
