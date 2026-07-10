// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/intermediate/wrapping/ARDCutIndexHeuristic.java

import Foundation

package final class ARDCutIndexHeuristic: ICutIndexCalculator {
    package init() {}

    package func getCutIndexes(
        _ graph: LGraph,
        _ gs: GraphStats
    ) -> [Int] {
        let rows = Self.getChunkCount(gs)

        // The number of cuts is one less than the number of rows.
        var cuts: [Int] = []
        let step = Double(gs.longestPath) / Double(rows)
        if rows > 1 {
            for idx in 1..<rows {
                cuts.append(Int(round(Double(idx) * step)))
            }
        }

        return cuts
    }

    package class func getChunkCount(_ gs: GraphStats) -> Int {
        let rowsd = sqrt(gs.getSumWidth() / (gs.dar * gs.getMaxHeight()))
        var rows = Int(round(rowsd))
        rows = min(rows, gs.longestPath)
        return rows
    }

    package func guaranteeValid() -> Bool {
        false
    }
}
