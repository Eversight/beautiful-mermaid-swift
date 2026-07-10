// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/EdgeLabelSideSelection.java

import Foundation

package enum EdgeLabelSideSelection {
    case ALWAYS_UP
    case ALWAYS_DOWN
    case DIRECTION_UP
    case DIRECTION_DOWN
    case SMART_UP
    case SMART_DOWN

    package func transpose() -> EdgeLabelSideSelection {
        switch self {
        case .ALWAYS_UP:
            return .ALWAYS_DOWN
        case .ALWAYS_DOWN:
            return .ALWAYS_UP
        case .DIRECTION_UP:
            return .DIRECTION_DOWN
        case .DIRECTION_DOWN:
            return .DIRECTION_UP
        case .SMART_UP:
            return .SMART_DOWN
        case .SMART_DOWN:
            return .SMART_UP
        }
    }
}
