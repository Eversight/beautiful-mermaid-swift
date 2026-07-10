// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/WrappingStrategy.java

import Foundation

package enum WrappingStrategy {
    /// Off.
    case OFF
    /// At each cut point, only a single edge may wrap backwards. Consequently it is only
    /// possible to cut between pairs of layers that are connected (and spanned) by a single edge.
    case SINGLE_EDGE
    /// It is allowed that multiple edges wrap backwards at a cut point. An additional objective
    /// is thus to keep the number of edges wrapping backwards small.
    case MULTI_EDGE
}
