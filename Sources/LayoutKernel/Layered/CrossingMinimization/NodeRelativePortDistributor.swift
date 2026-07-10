// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/NodeRelativePortDistributor.java

import Foundation

package final class NodeRelativePortDistributor:
    AbstractBarycenterPortDistributor
{
    package convenience init() {
        self.init(0)
    }

    package override init(_ numLayers: Int) {
        super.init(numLayers)
    }

    @discardableResult
    package override func calculatePortRanks(
        _ node: LNode,
        _ rankSum: Float,
        _ type: PortType
    ) -> Float {
        switch type {
        case .INPUT:
            var inputCount = 0
            var northInputCount = 0
            for port in node.getPorts() {
                if !port.getIncomingEdges().isEmpty {
                    inputCount += 1
                    if port.getSide() == .NORTH {
                        northInputCount += 1
                    }
                }
            }

            let incr = 1.0 as Float / Float(inputCount + 1)
            var northPos = rankSum + Float(northInputCount) * incr
            var restPos = rankSum + 1 - incr
            for port in node.getPorts(.INPUT) {
                if port.getSide() == .NORTH {
                    setPortRank(port.id, northPos)
                    northPos -= incr
                } else {
                    setPortRank(port.id, restPos)
                    restPos -= incr
                }
            }

        case .OUTPUT:
            var outputCount = 0
            for port in node.getPorts() {
                if !port.getOutgoingEdges().isEmpty {
                    outputCount += 1
                }
            }

            let incr = 1.0 as Float / Float(outputCount + 1)
            var pos = rankSum + incr
            for port in node.getPorts(.OUTPUT) {
                setPortRank(port.id, pos)
                pos += incr
            }

        case .UNDEFINED:
            break
        }

        // Java: consumed rank is always 1 for node-relative strategy.
        return 1
    }
}
