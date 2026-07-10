// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p4nodes/bk/BKAligner.java

import Foundation

package final class BKAligner {
    package let layeredGraph: LGraph
    package let ni: NeighborhoodInformation

    package init(
        _ layeredGraph: LGraph,
        _ ni: NeighborhoodInformation
    ) {
        self.layeredGraph = layeredGraph
        self.ni = ni
    }

    /// Java source: BKAligner.verticalAlignment(BKAlignedLayout, Set<LEdge>)
    package func verticalAlignment(
        _ bal: BKAlignedLayout,
        _ markedEdges: Set<LEdge>
    ) {
        for layer in layeredGraph.getLayers() {
            for v in layer.getNodes() {
                bal.root[v.id] = v
                bal.align[v.id] = v
                bal.innerShift[v.id] = 0.0
            }
        }

        var layers = layeredGraph.getLayers()
        if bal.hdir == .LEFT {
            layers.reverse()
        }

        for layer in layers {
            var r = -1
            var nodes = layer.getNodes()

            if bal.vdir == .UP {
                r = Int.max
                nodes.reverse()
            }

            for v_i_k in nodes {
                let neighbors: [Pair<
                    LNode,
                    LEdge
                >] = bal.hdir == .LEFT ? ni.rightNeighbors[v_i_k.id] : ni.leftNeighbors[v_i_k.id]

                if neighbors.isEmpty {
                    continue
                }

                let d = neighbors.count
                let low = Int(floor((Double(d) + 1.0) / 2.0)) - 1
                let high = Int(ceil((Double(d) + 1.0) / 2.0)) - 1

                if bal.vdir == .UP {
                    var m = high
                    while m >= low {
                        if bal.align[v_i_k.id] === v_i_k {
                            let u_m_pair = neighbors[m]
                            if let u_m = u_m_pair.getFirst(),
                               let edge = u_m_pair.getSecond(),
                               !markedEdges.contains(edge),
                               r > ni.nodeIndex[u_m.id]
                            {
                                bal.align[u_m.id] = v_i_k
                                bal.root[v_i_k.id] = bal.root[u_m.id]
                                if let root = bal.root[v_i_k.id] {
                                    bal.align[v_i_k.id] = root
                                    bal.od[root.id] = bal.od[root.id] && v_i_k.getType() == .LONG_EDGE
                                }
                                r = ni.nodeIndex[u_m.id]
                            }
                        }
                        m -= 1
                    }
                } else {
                    for m in low ... high {
                        if bal.align[v_i_k.id] === v_i_k {
                            let um_pair = neighbors[m]
                            if let um = um_pair.getFirst(),
                               let edge = um_pair.getSecond(),
                               !markedEdges.contains(edge),
                               r < ni.nodeIndex[um.id]
                            {
                                bal.align[um.id] = v_i_k
                                bal.root[v_i_k.id] = bal.root[um.id]
                                if let root = bal.root[v_i_k.id] {
                                    bal.align[v_i_k.id] = root
                                    bal.od[root.id] = bal.od[root.id] && v_i_k.getType() == .LONG_EDGE
                                }
                                r = ni.nodeIndex[um.id]
                            }
                        }
                    }
                }
            }
        }
    }

    /// Java source: BKAligner.insideBlockShift(BKAlignedLayout)
    package func insideBlockShift(_ bal: BKAlignedLayout) {
        let blocks = BKNodePlacer.getBlocks(bal)
        var seenRoots: Set<ObjectIdentifier> = []

        for layer in layeredGraph.getLayers() {
            for candidate in layer.getNodes() {
                guard let root = bal.root[candidate.id] else {
                    continue
                }
                let rootKey = ObjectIdentifier(root)
                if seenRoots.contains(rootKey) || blocks[root] == nil {
                    continue
                }
                seenRoots.insert(rootKey)

                var spaceAbove = root.getMargin().top
                var spaceBelow = root.getSize().y + root.getMargin().bottom
                bal.innerShift[root.id] = 0.0

                var current = root
                while let next = bal.align[current.id], next !== root {
                    guard let edge = BKNodePlacer.getEdge(current, next),
                          let source = edge.getSource(),
                          let target = edge.getTarget()
                    else {
                        current = next
                        continue
                    }

                    let portPosDiff: Double
                    if bal.hdir == .LEFT {
                        portPosDiff = target.getPosition().y + target.getAnchor().y
                            - source.getPosition().y - source.getAnchor().y
                    } else {
                        portPosDiff = source.getPosition().y + source.getAnchor().y
                            - target.getPosition().y - target.getAnchor().y
                    }

                    let nextInnerShift = bal.innerShift[current.id] + portPosDiff
                    bal.innerShift[next.id] = nextInnerShift

                    spaceAbove = Swift.max(spaceAbove, next.getMargin().top - nextInnerShift)
                    spaceBelow = Swift.max(
                        spaceBelow,
                        nextInnerShift + next.getSize().y + next.getMargin().bottom
                    )

                    current = next
                }

                current = root
                repeat {
                    bal.innerShift[current.id] += spaceAbove
                    guard let next = bal.align[current.id] else {
                        break
                    }
                    current = next
                } while current !== root

                bal.blockSize[root.id] = spaceAbove + spaceBelow
            }
        }
    }
}
