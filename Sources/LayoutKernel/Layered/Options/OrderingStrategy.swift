// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/OrderingStrategy.java

import Foundation

/// Strategy to order nodes and ports before crossing minimization.
package enum OrderingStrategy: String {
    /// Nothing is ordered.
    case NONE

    /// Nodes and edges are ordered.
    case NODES_AND_EDGES

    /// Node ordering is used only as a secondary criterion. Edge order is preserved.
    case PREFER_EDGES

    /// Prefer node order.
    case PREFER_NODES
}
