import XCTest
@testable import LayoutKernel
import Foundation

/// Captures structured per-phase snapshots of the ELK layered pipeline.
///
/// Uses the existing `TestExecutionState` / `runLayoutTestStep()` API to step
/// through processors one-by-one, taking a JSON snapshot after each of the 5
/// main phases (P1-P5).
///
/// Output JSON format matches `verification/tools/elkjs-phase-snapshot.js`
/// so that `compare-phases.py` can diff them directly.
///
/// Usage:
///   swift test --filter ElkPhaseSnapshotTest
///
/// The snapshot JSON is written to:
///   $PHASE_SNAPSHOT_OUTPUT  (env var, default: /tmp/elk-swift-phase-snapshot.json)
///
/// Set PHASE_SNAPSHOT_DIAGRAM to choose a diagram (default: class-13-labels).
/// Set PHASE_SNAPSHOT_JSON to provide inline ELK JSON instead.
final class ElkPhaseSnapshotTest: XCTestCase {

    // MARK: - Built-in diagrams

    static let diagrams: [String: String] = [
        "class-13-labels": """
        {"id":"root","layoutOptions":{"elk.algorithm":"layered","elk.direction":"DOWN",\
        "elk.spacing.nodeNode":"40","elk.layered.spacing.nodeNodeBetweenLayers":"60",\
        "elk.padding":"[top=40,left=40,bottom=40,right=40]","elk.edgeRouting":"ORTHOGONAL",\
        "elk.edgeLabels.placement":"CENTER"},\
        "children":[{"id":"Teacher","width":120,"height":68},\
        {"id":"Student","width":120,"height":68},\
        {"id":"Course","width":120,"height":68}],\
        "edges":[{"id":"e0","sources":["Teacher"],"targets":["Course"],\
        "labels":[{"text":"teaches","width":56,"height":21}]},\
        {"id":"e1","sources":["Student"],"targets":["Course"],\
        "labels":[{"text":"enrolled in","width":82,"height":21}]}]}
        """
    ]

    // MARK: - Phase identification

    /// Map processor type names to phases.
    static let phasePatterns: [(pattern: String, phase: String)] = [
        ("CycleBreaker",              "p1-cycle-breaking"),
        ("InteractiveCycleBreaker",   "p1-cycle-breaking"),
        ("GreedyCycleBreaker",        "p1-cycle-breaking"),
        ("DepthFirstCycleBreaker",    "p1-cycle-breaking"),
        ("NetworkSimplexLayerer",     "p2-layering"),
        ("LongestPathLayerer",        "p2-layering"),
        ("InteractiveLayerer",        "p2-layering"),
        ("CoffmanGrahamLayerer",      "p2-layering"),
        ("LayerSweepCrossingMinimizer", "p3-crossing-minimization"),
        ("InteractiveCrossingMinimizer", "p3-crossing-minimization"),
        ("BKNodePlacer",              "p4-node-placement"),
        ("LinearSegmentsNodePlacer",  "p4-node-placement"),
        ("NetworkSimplexPlacer",      "p4-node-placement"),
        ("OrthogonalEdgeRouter",      "p5-edge-routing"),
        ("PolylineEdgeRouter",        "p5-edge-routing"),
        ("SplineEdgeRouter",          "p5-edge-routing"),
    ]

    static func classifyProcessor(_ processor: Any) -> String? {
        let name = String(describing: type(of: processor))
        for (pattern, phase) in phasePatterns {
            if name.contains(pattern) { return phase }
        }
        return nil
    }

    // MARK: - Snapshot capture

    static func captureSnapshot(
        _ graphs: [LGraph],
        slotIndex: Int,
        processorName: String
    ) -> [String: Any] {
        guard let lgraph = graphs.first else {
            return ["slotIndex": slotIndex, "processor": processorName, "layers": [] as [Any]]
        }

        var layersData: [[String: Any]] = []
        for (li, layer) in lgraph.getLayers().enumerated() {
            var nodesData: [[String: Any]] = []
            for node in layer.getNodes() {
                var nodeDict: [String: Any] = [
                    "id": node.id,
                    "type": String(describing: node.getType()),
                    "position": ["x": node.getPosition().x, "y": node.getPosition().y],
                    "size": ["w": node.getSize().x, "h": node.getSize().y],
                ]

                // Origin identifier
                if let elk = node.getProperty(InternalProperties.ORIGIN) as? GraphNode,
                   let id = elk.identifier, !id.isEmpty {
                    nodeDict["origin"] = id
                } else if let elk = node.getProperty(InternalProperties.ORIGIN) as? GraphNode,
                          let lbl = elk.labels.first?.text, !lbl.isEmpty {
                    nodeDict["origin"] = lbl
                }

                // Ports in current order
                var portsData: [[String: Any]] = []
                for port in node.getPorts() {
                    var portDict: [String: Any] = [
                        "id": port.id,
                        "side": String(describing: port.getSide()),
                        "position": ["x": port.getPosition().x, "y": port.getPosition().y],
                    ]

                    var incoming: [[String: Any]] = []
                    for edge in port.getIncomingEdges() {
                        if let src = edge.getSource() {
                            incoming.append([
                                "sourceNode": src.getNode()?.id ?? -1,
                                "sourcePort": src.id
                            ])
                        }
                    }
                    portDict["incoming"] = incoming

                    var outgoing: [[String: Any]] = []
                    for edge in port.getOutgoingEdges() {
                        if let tgt = edge.getTarget() {
                            outgoing.append([
                                "targetNode": tgt.getNode()?.id ?? -1,
                                "targetPort": tgt.id
                            ])
                        }
                    }
                    portDict["outgoing"] = outgoing

                    portsData.append(portDict)
                }
                nodeDict["ports"] = portsData
                nodesData.append(nodeDict)
            }
            layersData.append(["index": li, "nodes": nodesData])
        }

        // Also capture layerless nodes (before P2)
        var layerlessData: [[String: Any]] = []
        for node in lgraph.getLayerlessNodes() {
            var d: [String: Any] = [
                "id": node.id,
                "type": String(describing: node.getType()),
            ]
            if let elk = node.getProperty(InternalProperties.ORIGIN) as? GraphNode,
               let id = elk.identifier, !id.isEmpty {
                d["origin"] = id
            }
            layerlessData.append(d)
        }

        var result: [String: Any] = [
            "slotIndex": slotIndex,
            "processor": processorName,
            "layers": layersData,
        ]
        if !layerlessData.isEmpty {
            result["layerlessNodes"] = layerlessData
        }
        return result
    }

    // MARK: - Test

    func testCapturePhaseSnapshots() throws {
        let env = ProcessInfo.processInfo.environment
        let diagramId = env["PHASE_SNAPSHOT_DIAGRAM"] ?? "class-13-labels"
        let outputPath = env["PHASE_SNAPSHOT_OUTPUT"]
            ?? "/tmp/elk-swift-phase-snapshot.json"

        // Get ELK JSON
        let jsonString: String
        if let inline = env["PHASE_SNAPSHOT_JSON"] {
            jsonString = inline
        } else if let builtin = Self.diagrams[diagramId] {
            jsonString = builtin
        } else {
            XCTFail("Unknown diagram: \(diagramId)")
            return
        }

        // Parse and import
        let data = jsonString.data(using: .utf8)!
        let graph = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let importer = JsonImporter()
        let elkGraph = importer.transform(graph)

        let monitor = BasicProgressMonitor()
        let graphTransformer = LayeredGraphTransformer()
        guard let layeredGraph = try graphTransformer.importGraph(elkGraph) else {
            XCTFail("Failed to import graph")
            return
        }

        // Use the test execution API to step through processors
        let provider = LayeredLayoutProvider()
        let elkLayered = provider.getLayoutAlgorithm()

        // Prepare: this calls graphConfigurator.prepareGraphForLayout and componentsProcessor.split
        let state = elkLayered.prepareLayoutTest(layeredGraph)
        let processors = elkLayered.getLayoutTestConfiguration(state)

        var allProcessors: [[String: Any]] = []
        var phaseSnapshots: [String: [String: Any]] = [:]

        // Step through each processor
        for (index, processor) in processors.enumerated() {
            let procName = String(describing: type(of: processor))

            // Run this processor
            elkLayered.runLayoutTestStep(state)

            // Capture snapshot
            let snapshot = Self.captureSnapshot(
                state.getGraphs(),
                slotIndex: index,
                processorName: procName
            )

            // Classify phase
            let phase = Self.classifyProcessor(processor)
            var entry: [String: Any] = ["slot": index, "processor": procName]
            if let phase = phase {
                entry["phase"] = phase
                // Keep last snapshot per phase (the main phase processor)
                phaseSnapshots[phase] = snapshot
            }
            allProcessors.append(entry)
        }

        // Apply layout back to LayoutGraphProtocol (for completeness)
        // Note: after stepping through all processors, the state graphs
        // have the final layout applied internally.

        // Build output
        var output: [String: Any] = [
            "diagram": diagramId,
            "source": "swift",
            "allProcessors": allProcessors,
        ]

        // Add phase snapshots
        var phases: [String: Any] = [:]
        let phaseKeys = [
            "p1-cycle-breaking", "p2-layering", "p3-crossing-minimization",
            "p4-node-placement", "p5-edge-routing"
        ]
        for key in phaseKeys {
            if let snap = phaseSnapshots[key] {
                phases[key] = snap
            }
        }
        output["phases"] = phases

        // Write JSON
        let jsonData = try JSONSerialization.data(
            withJSONObject: output,
            options: [.prettyPrinted, .sortedKeys]
        )
        let jsonStr = String(data: jsonData, encoding: .utf8)!

        try jsonStr.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Phase snapshot written to: \(outputPath)")

        // Also print a summary to stdout
        print("\nProcessor pipeline (\(processors.count) processors):")
        for entry in allProcessors {
            let slot = entry["slot"] as? Int ?? 0
            let name = entry["processor"] as? String ?? "?"
            let phase = entry["phase"] as? String ?? ""
            let marker = phase.isEmpty ? "  " : "⬤ "
            print("  [\(String(format: "%2d", slot))] \(marker)\(name)\(phase.isEmpty ? "" : "  ← \(phase)")")
        }

        // Print port orders for key nodes after P3
        if let p3 = phaseSnapshots["p3-crossing-minimization"],
           let layers = p3["layers"] as? [[String: Any]] {
            print("\nPort orders after P3:")
            for layerData in layers {
                let li = layerData["index"] as? Int ?? 0
                let nodes = layerData["nodes"] as? [[String: Any]] ?? []
                for nodeData in nodes {
                    let nid = nodeData["id"] as? Int ?? 0
                    let origin = nodeData["origin"] as? String ?? nodeData["type"] as? String ?? "?"
                    let ports = nodeData["ports"] as? [[String: Any]] ?? []
                    let portSummary = ports.map { p -> String in
                        let pid = p["id"] as? Int ?? 0
                        let side = p["side"] as? String ?? "?"
                        let inc = p["incoming"] as? [[String: Any]] ?? []
                        let out = p["outgoing"] as? [[String: Any]] ?? []
                        let conns = inc.map { "←n\($0["sourceNode"] ?? "?")" }
                            + out.map { "→n\($0["targetNode"] ?? "?")" }
                        return "p\(pid)(\(side),\(conns.joined(separator: ",")))"
                    }.joined(separator: ", ")
                    print("  L\(li) #\(nid) \(origin): [\(portSummary)]")
                }
            }
        }
    }
}
