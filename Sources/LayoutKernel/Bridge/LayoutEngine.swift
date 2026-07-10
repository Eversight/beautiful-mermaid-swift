// ELK — public entry point for the native Swift layout engine.
// Pure Swift port of Eclipse Layout Kernel (Java).

import Foundation
import Synchronization

public final class LayoutEngine {

    public enum Error: Swift.Error, LocalizedError {
        case runtimeError(String)
        case invalidResult
        case timedOut(TimeInterval)

        public var errorDescription: String? {
            switch self {
            case .runtimeError(let message):
                return "ELK layout error: \(message)"
            case .invalidResult:
                return "ELK returned an invalid graph"
            case .timedOut(let timeout):
                return "ELK layout timed out after \(timeout)s"
            }
        }
    }

    private let engine: RecursiveGraphLayoutEngine

    /// Whether the layered algorithm has been registered.
    private static let _algorithmsRegistered = Mutex(false)

    public init() {
        engine = RecursiveGraphLayoutEngine()
        LayoutEngine.registerAlgorithmsIfNeeded()
    }

    /// Register the layered layout algorithm with the metadata service.
    /// The mutex serializes first-time registration; `LayoutMetaDataService`
    /// takes its own locks, so no lock is ever acquired reentrantly here.
    private static func registerAlgorithmsIfNeeded() {
        _algorithmsRegistered.withLock { registered in
            guard !registered else { return }
            registered = true

            registerAlgorithms()
        }
    }

    private static func registerAlgorithms() {
        let service = LayoutMetaDataService.getInstance()

        // Register the layered algorithm
        let layeredData = LayoutAlgorithmData.Builder()
            .id("org.eclipse.elk.layered")
            .name("ELK Layered")
            .providerFactory(LayoutProviderFactory(provider: { LayeredLayoutProvider() }))
            .supportedFeatures([
                .selfLoops,
                .insideSelfLoops,
                .multiEdges,
                .edgeLabels,
                .ports,
                .compound,
                .clusters
            ])
            .create()

        service.registerAlgorithm(layeredData)
    }

    /// Layout a graph specified as a JSON-compatible dictionary.
    public func layout(
        graph: [String: Any],
        options: [String: Any]? = nil,
        timeout: TimeInterval = 30
    ) throws -> [String: Any] {
        // 1. Import: [String: Any] → GraphNode
        let importer = JsonImporter()
        let elkGraph = importer.transform(graph)
        // The imported graph is transient and internally cyclic (shape ↔ edge,
        // section ↔ section); tear it down after export or it leaks (the Java
        // original relies on GC).
        defer { LayoutEngine.tearDownGraph(elkGraph) }

        // 2. Merge top-level options if provided
        if let options = options {
            for (key, value) in options {
                elkGraph.setProperty(key, value)
            }
        }

        // 3. Run layout
        let monitor = TimeoutProgressMonitor(timeout: timeout)
        try engine.layout(layoutGraph: elkGraph, progressMonitor: monitor)
        if monitor.isCanceled() {
            throw Error.timedOut(timeout)
        }

        // 4. Export: GraphNode → [String: Any]
        let exporter = JsonExporter()
        return exporter.export(elkGraph)
    }

    /// Breaks the reference cycles inside a transient imported graph so ARC
    /// can free it: shapes and edges reference each other strongly, as do
    /// consecutive edge sections (parent references are already weak). Only
    /// downward tree references remain afterwards.
    private static func tearDownGraph(_ root: GraphNode) {
        var nodes: [GraphNode] = [root]
        while let node = nodes.popLast() {
            node.outgoingEdges.removeAll()
            node.incomingEdges.removeAll()
            for port in node.ports {
                port.outgoingEdges.removeAll()
                port.incomingEdges.removeAll()
            }
            for edge in node.containedEdges {
                for section in edge.sections {
                    section.outgoingSections.removeAll()
                    section.incomingSections.removeAll()
                }
            }
            nodes.append(contentsOf: node.children)
        }
    }
}

// MARK: - Layout Provider Factory

/// Simple IFactory implementation that creates layout provider instances.
private final class LayoutProviderFactory: IFactory {
    private let createFn: () -> AbstractLayoutProvider

    init(provider: @escaping () -> AbstractLayoutProvider) {
        self.createFn = provider
    }

    func create() -> Any {
        return createFn()
    }

    func destroy(_ obj: Any) {
        // No-op: layout providers don't hold external resources.
    }
}
