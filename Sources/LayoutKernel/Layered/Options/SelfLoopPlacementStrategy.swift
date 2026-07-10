// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/SelfLoopPlacementStrategy.java

import Foundation

package enum SelfLoopPlacementStrategy {
    /// Distributes the loops equally around the node.
    case EQUALLY_DISTRIBUTED
    /// Stacks all loops to the north side of the node.
    case NORTH_STACKED
    /// Loops are placed sequentially (next to each other) to the north side of the node.
    case NORTH_SEQUENCE
}
