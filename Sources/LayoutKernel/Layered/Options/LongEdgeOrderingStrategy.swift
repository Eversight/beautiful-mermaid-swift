// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/LongEdgeOrderingStrategy.java

import Foundation

package enum LongEdgeOrderingStrategy {
    case DUMMY_NODE_OVER
    case DUMMY_NODE_UNDER
    case EQUAL

    package func returnValue() -> Int {
        switch self {
        case .DUMMY_NODE_OVER:
            return Int(Int32.max)
        case .DUMMY_NODE_UNDER:
            return Int(Int32.min)
        case .EQUAL:
            return 0
        }
    }
}
