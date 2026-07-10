// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/LayerTotalPortDistributor.java

import Foundation

package final class LayerTotalPortDistributor:
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

            var northPos = rankSum + Float(northInputCount)
            var restPos = rankSum + Float(inputCount)
            for port in node.getPorts(.INPUT) {
                if port.getSide() == .NORTH {
                    setPortRank(port.id, northPos)
                    northPos -= 1
                } else {
                    setPortRank(port.id, restPos)
                    restPos -= 1
                }
            }
            return Float(inputCount)

        case .OUTPUT:
            var pos = 0
            for port in node.getPorts(.OUTPUT) {
                pos += 1
                let rank = rankSum + Float(pos)
                setPortRank(port.id, rank)
            }
            return Float(pos)

        case .UNDEFINED:
            return 0
        }
    }
}
