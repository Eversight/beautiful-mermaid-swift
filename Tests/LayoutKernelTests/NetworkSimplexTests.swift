// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of ELK network simplex tests.

import XCTest
@testable import LayoutKernel

final class NetworkSimplexTests: XCTestCase {

    /// Random with a fixed seed for determinism, matching Java new Random(1).
    private var random: Random!

    override func setUp() {
        super.setUp()
        random = Random(seed: 1)
    }

    func testDeltas() {
        for _ in 0..<5 {
            let n = 5
            for _ in 0..<n {
                let graph = generateRandomGraph()

                XCTAssertTrue(graph.isAcyclic(), "Graph should be acyclic")

                NetworkSimplex.forGraph(graph).execute(BasicProgressMonitor())

                for node in graph.nodes {
                    for edge in node.getOutgoingEdges() {
                        guard let target = edge.target, let source = edge.source else {
                            XCTFail("Edge has nil source or target")
                            continue
                        }
                        XCTAssertGreaterThanOrEqual(
                            target.layer - source.layer,
                            edge.delta,
                            "Valid delta: target.layer(\(target.layer)) - source.layer(\(source.layer)) >= delta(\(edge.delta))")
                    }
                }
            }
        }
    }

    private func generateRandomGraph() -> NGraph {
        let graph = NGraph()

        let n = 4000
        let e = 8000

        // Create nodes
        for i in 0..<n {
            _ = NNode.of().id(i).create(graph)
        }

        // Create edges
        for _ in 0..<e {
            var src = random.nextInt(n)
            var tgt = random.nextInt(n)
            // No self loops
            while src == tgt {
                tgt = random.nextInt(n)
            }

            _ = NEdge.of()
                .delta(random.nextInt(50))
                .weight(random.nextDouble() * 50)
                .source(graph.nodes[src])
                .target(graph.nodes[tgt])
                .create()
        }

        // Assert connectedness
        for i in 0..<(n - 1) {
            _ = NEdge.of()
                .delta(random.nextInt(50))
                .weight(random.nextDouble() * 50)
                .source(graph.nodes[i])
                .target(graph.nodes[i + 1])
                .create()
        }

        // Assert acyclic: reverse edges where source.id > target.id
        for node in graph.nodes {
            for edge in Array(node.getOutgoingEdges()) {
                if let source = edge.source, let target = edge.target,
                   source.id > target.id {
                    _ = edge.reverse()
                }
            }
        }

        return graph
    }
}
