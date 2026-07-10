/// S2' step 3: flat constraint resolution mirroring `ForsterConstraintResolver`
/// (docs/SweepEngineContract.md §6 traps 1-2). Runs after every barycenter
/// sort; groups nodes bound by in-layer successor constraints and layout
/// units, merges violated pairs, and rebuilds the layer from group order.
///
/// Identity semantics: the object code compares groups by reference
/// (`===`, `indexOf` by identity, `removeOutgoingConstraint` by identity).
/// Here every group gets a serial id into `store`; the current list holds
/// ids in order, so identity comparisons become id comparisons and the
/// object's linear scans stay linear scans.
///
/// Reproduced quirks (do NOT "fix" — golden-enshrined, contract §6.1):
/// - Persistent object groups capture `summedWeight`/`degree` BEFORE the
///   BarycenterState is stored, so both are always 0 and merged groups take
///   the `(b1+b2)/2` averaging branch, cascaded per merge.
/// - `out` constraint lists are Optional: a nil list and an empty list pick
///   different merge branches, which changes duplicate-decrement behavior.
/// - Nil barycenters compare as `Float.nan` in the equality probe (never
///   equal), then as ±infinity substitutes in the greater-than probe.
extension SweepEngine {

    private struct ForsterGroup {
        var nodes: [Int32]
        var out: [Int]?
        var incoming: [Int]?
        var incomingCount: Int = 0
    }

    /// `ForsterConstraintResolver.processConstraints(&nodes)` for the v1
    /// subset (`constraintsBetweenNonDummies == false` — the property
    /// defaults false and nothing in the Mermaid pipeline sets it).
    package mutating func processConstraints(_ layer: inout [Int32]) {
        // Fresh single-node groups in layer order; serial id == initial index.
        var store = [ForsterGroup]()
        store.reserveCapacity(layer.count)
        var groupOf = [Int32: Int](minimumCapacity: layer.count)
        for node in layer {
            groupOf[node] = store.count
            store.append(ForsterGroup(nodes: [node]))
        }
        var list = Array(0..<store.count)

        buildConstraintsGraph(&store, list, groupOf)

        while let violated = findViolatedConstraint(&store, list) {
            handleViolatedConstraint(violated.0, violated.1, &store, &list)
        }

        var resolved = [Int32]()
        resolved.reserveCapacity(layer.count)
        for id in list {
            let groupHas: Bool
            let groupValue: Double
            if let first = store[id].nodes.first {
                groupHas = hasBarycenter[Int(first)]
                groupValue = barycenter[Int(first)]
            } else {
                groupHas = false
                groupValue = 0
            }
            for node in store[id].nodes {
                resolved.append(node)
                hasBarycenter[Int(node)] = groupHas
                barycenter[Int(node)] = groupValue
            }
        }
        layer = resolved
    }

    /// `buildConstraintsGraph(groups, onlyBetweenNormalNodes: false)`.
    private func buildConstraintsGraph(
        _ store: inout [ForsterGroup], _ list: [Int], _ groupOf: [Int32: Int]
    ) {
        var lastNonDummyNode: Int32 = -1

        for id in list {
            // All groups are single-node here (built moments ago).
            let node = store[id].nodes[0]
            let n = Int(node)

            for i in Int(graph.inLayerSuccessorsStart[n])..<Int(graph.inLayerSuccessorsStart[n + 1]) {
                let successor = graph.inLayerSuccessors[i]
                guard let successorGroup = groupOf[successor] else {
                    // The object code would mutate a persistent group outside
                    // this layer; that mutation is wiped by the next
                    // buildConstraintsGraph before anyone reads it.
                    assertionFailure("in-layer successor constraint points outside the layer")
                    continue
                }
                store[id].out = (store[id].out ?? []) + [successorGroup]
                store[successorGroup].incomingCount += 1
            }

            if graph.isNormalNode[n] {
                if lastNonDummyNode >= 0 {
                    for lastUnitNode in layoutUnitNodes(of: lastNonDummyNode) {
                        for currentUnitNode in layoutUnitNodes(of: node) {
                            guard let lastGroup = groupOf[lastUnitNode],
                                  let currentGroup = groupOf[currentUnitNode] else {
                                assertionFailure("layout-unit member outside the layer")
                                continue
                            }
                            store[lastGroup].out = (store[lastGroup].out ?? []) + [currentGroup]
                            store[currentGroup].incomingCount += 1
                        }
                    }
                }
                lastNonDummyNode = node
            }
        }
    }

    /// `layoutUnitNodes(for:)`: the unit's member list, else the node itself.
    private func layoutUnitNodes(of node: Int32) -> ArraySlice<Int32> {
        let n = Int(node)
        let range = Int(graph.unitMembersStart[n])..<Int(graph.unitMembersStart[n + 1])
        if range.isEmpty {
            return [node][...]
        }
        return graph.unitMembers[range]
    }

    private func groupBarycenter(_ store: [ForsterGroup], _ id: Int) -> Double? {
        guard let first = store[id].nodes.first, hasBarycenter[Int(first)] else { return nil }
        return barycenter[Int(first)]
    }

    /// `findViolatedConstraint`: FIFO over zero-in-degree groups, incoming
    /// lists rebuilt by PREPENDING, Float-narrowed equality with the indexOf
    /// tie-break, ±infinity substitution in the greater-than probe.
    private func findViolatedConstraint(
        _ store: inout [ForsterGroup], _ list: [Int]
    ) -> (Int, Int)? {
        var queue = [Int]()
        var head = 0

        for id in list {
            store[id].incoming = nil
            if !(store[id].out ?? []).isEmpty && store[id].incomingCount == 0 {
                queue.append(id)
            }
        }

        while head < queue.count {
            let id = queue[head]
            head += 1

            if !(store[id].incoming ?? []).isEmpty {
                let groupBary = groupBarycenter(store, id)
                for predecessor in store[id].incoming ?? [] {
                    let predBary = groupBarycenter(store, predecessor)
                    if Float(predBary ?? .nan) == Float(groupBary ?? .nan) {
                        if indexOf(list, predecessor) > indexOf(list, id) {
                            return (predecessor, id)
                        }
                    } else if (predBary ?? -.infinity) > (groupBary ?? .infinity) {
                        return (predecessor, id)
                    }
                }
            }

            for successor in store[id].out ?? [] {
                store[successor].incoming = [id] + (store[successor].incoming ?? [])
                if store[successor].incomingCount == (store[successor].incoming ?? []).count {
                    queue.append(successor)
                }
            }
        }
        return nil
    }

    private func indexOf(_ list: [Int], _ id: Int) -> Int {
        list.firstIndex(of: id) ?? -1
    }

    /// `handleViolatedConstraint`: merge the pair into a new group, splice it
    /// into the ordered list before the first strictly-greater barycenter,
    /// and rewire third-party constraints.
    private mutating func handleViolatedConstraint(
        _ first: Int, _ second: Int, _ store: inout [ForsterGroup], _ list: inout [Int]
    ) {
        // ConstraintGroup(first, second): nodes concatenated; outgoing merged
        // with the nil/empty distinction; barycenter from the (degree == 0)
        // averaging cascade, written to every member's state.
        var merged = ForsterGroup(nodes: store[first].nodes + store[second].nodes)
        if let out1 = store[first].out {
            var combined = out1.filter { $0 != second }
            if let out2 = store[second].out {
                for candidate in out2 {
                    if candidate == first { continue }
                    if combined.contains(candidate) {
                        store[candidate].incomingCount -= 1
                    } else {
                        combined.append(candidate)
                    }
                }
            }
            merged.out = combined
        } else if let out2 = store[second].out {
            merged.out = out2.filter { $0 != first }
        }

        let b1 = groupBarycenter(store, first)
        let b2 = groupBarycenter(store, second)
        let newBarycenter: Double?
        if let b1, let b2 {
            newBarycenter = (b1 + b2) / 2
        } else {
            newBarycenter = b1 ?? b2
        }
        if let newBarycenter {
            for node in merged.nodes {
                barycenter[Int(node)] = newBarycenter
                hasBarycenter[Int(node)] = true
            }
        }

        let newId = store.count
        store.append(merged)

        var i = 0
        var alreadyInserted = false
        while i < list.count {
            let id = list[i]

            if id == first || id == second {
                list.remove(at: i)
                continue
            }

            if !alreadyInserted,
               let currentBarycenter = groupBarycenter(store, id),
               let newBary = newBarycenter,
               currentBarycenter > newBary
            {
                list.insert(newId, at: i)
                alreadyInserted = true
                i += 1
                continue
            }

            if !(store[id].out ?? []).isEmpty {
                let before = store[id].out?.count ?? 0
                store[id].out?.removeAll { $0 == first || $0 == second }
                if (store[id].out?.count ?? 0) != before {
                    store[id].out?.append(newId)
                    store[newId].incomingCount += 1
                }
            }

            i += 1
        }

        if !alreadyInserted {
            list.append(newId)
        }
    }
}
