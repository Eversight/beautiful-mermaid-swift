import SwiftUI
import CoreGraphics

/// A value-type model that manages the Mermaid diagram pipeline (parse -> layout -> render).
///
/// Mutations run synchronously, and each input re-runs only the pipeline
/// stages it affects: `source` re-parses and re-lays-out; `layoutConfig`
/// re-lays-out the already-parsed graph; `theme` only swaps the draw colors
/// (no parsing or layout). Hold it in `@State` to drive a ``MermaidDiagramView``.
///
/// Usage:
/// ```swift
/// @State private var diagram = MermaidDiagram(source: "graph TD; A-->B")
///
/// var body: some View {
///     MermaidDiagramView(diagram)
///         .frame(height: 300)
/// }
/// ```
public struct MermaidDiagram {

    public var source: String {
        didSet { if source != oldValue { reparse() } }
    }

    public var theme: DiagramTheme {
        didSet { if theme != oldValue { rebuildRenderClosure() } }
    }

    public var layoutConfig: LayoutConfig {
        didSet { if layoutConfig != oldValue { relayout() } }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    private var parsedGraph: MermaidGraph?
    private var positionedGraph: PositionedGraph?

    public init(
        source: String = "",
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        reparse()
    }

    private mutating func reparse() {
        parsedGraph = nil
        guard !source.isEmpty else {
            clearOutputs(error: nil)
            return
        }
        do {
            parsedGraph = try MermaidParser.parse(source)
            relayout()
        } catch {
            clearOutputs(error: error)
        }
    }

    private mutating func relayout() {
        guard let graph = parsedGraph else {
            if !source.isEmpty { reparse() }
            return
        }
        do {
            positionedGraph = try GraphLayout(config: layoutConfig).layout(graph)
            diagramBounds = CGRect(
                x: 0, y: 0,
                width: max(1, positionedGraph!.width),
                height: max(1, positionedGraph!.height))
            parseError = nil
            rebuildRenderClosure()
        } catch {
            clearOutputs(error: error)
        }
    }

    private mutating func rebuildRenderClosure() {
        guard let positioned = positionedGraph else { return }
        let renderer = DiagramRenderer(theme: theme)
        preparedDiagram = PreparedDiagram(bounds: diagramBounds) { context, renderBounds in
            renderer.render(positioned, in: context, bounds: renderBounds)
        }
    }

    private mutating func clearOutputs(error: Error?) {
        parseError = error
        positionedGraph = nil
        preparedDiagram = nil
        diagramBounds = .zero
    }
}

// MARK: - MermaidDiagramView convenience init for the value-type model

#if canImport(UIKit)
import UIKit

@available(iOS 16.0, macCatalyst 16.0, visionOS 1.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#elseif canImport(AppKit)
import AppKit

@available(macOS 13.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#endif
