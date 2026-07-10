// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/ValidifyStrategy.java

import Foundation

package enum ValidifyStrategy {
    /// Do not touch my cuts!.
    case NO
    /// Just increase forbidden cuts until they are valid.
    case GREEDY
    /// Be a bit smarter and check if the lastly valid cut is closer than the next valid cut.
    case LOOK_BACK
}
