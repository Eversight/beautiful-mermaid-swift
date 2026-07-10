// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/SelfLoopOrderingStrategy.java

import Foundation

package enum SelfLoopOrderingStrategy {
    /// Self loops will be stacked or nested high.
    case STACKED
    /// Self loops will be stacked or nested high with the first self loop on top.
    case REVERSE_STACKED
    /// Self loops will be placed next to each other.
    case SEQUENCED
}
