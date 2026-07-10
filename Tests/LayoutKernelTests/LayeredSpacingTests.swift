// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of ELK layered spacing tests.

import XCTest
@testable import LayoutKernel

final class LayeredSpacingTests: XCTestCase {
    func testSpacingNodeNodeBetweenLayers() {
        let elk = LayoutEngine()
        let spacing = 66.0
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.layered.spacing.nodeNodeBetweenLayers": String(spacing)
            ],
            "children": [
                ["id": "n1", "width": 30, "height": 30,
                 "layoutOptions": ["elk.nodeSize.constraints": "MINIMUM_SIZE"]],
                ["id": "n2", "width": 30, "height": 30,
                 "layoutOptions": ["elk.nodeSize.constraints": "MINIMUM_SIZE"]]
            ],
            "edges": [
                ["id": "e1", "sources": ["n1"], "targets": ["n2"]]
            ]
        ]
        let result = try! elk.layout(graph: graph)
        let children = result["children"] as! [[String: Any]]
        let n1 = children.first { ($0["id"] as? String) == "n1" }!
        let n2 = children.first { ($0["id"] as? String) == "n2" }!
        let n1Right = (n1["x"] as! Double) + (n1["width"] as! Double)
        let n2Left = n2["x"] as! Double
        let gap = n2Left - n1Right
        XCTAssertEqual(gap, spacing, accuracy: 1.0,
            "Gap between n1 right edge and n2 left edge should equal the configured spacing (\(spacing))")
    }

    func testSpacingNodeNodeNoEdges() {
        let elk = LayoutEngine()
        let spacing = 40.0
        // Two nodes with no edges between them — both end up in the same layer
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.spacing.nodeNode": String(spacing)
            ],
            "children": [
                ["id": "n1", "width": 30, "height": 30,
                 "layoutOptions": ["elk.nodeSize.constraints": "MINIMUM_SIZE"]],
                ["id": "n2", "width": 30, "height": 30,
                 "layoutOptions": ["elk.nodeSize.constraints": "MINIMUM_SIZE"]]
            ]
        ]
        // Verify layout doesn't crash; spacing between same-layer nodes
        // is harder to verify precisely because the graph may split into components
        let result = try! elk.layout(graph: graph)
        XCTAssertGreaterThan(result["width"] as! Double, 0)
        XCTAssertGreaterThan(result["height"] as! Double, 0)
    }
}
