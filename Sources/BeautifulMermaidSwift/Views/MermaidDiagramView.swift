import SwiftUI

#if canImport(UIKit)
import UIKit

/// A SwiftUI view that renders a Mermaid diagram.
@available(iOS 16.0, macCatalyst 16.0, visionOS 1.0, *)
public struct MermaidDiagramView: UIViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self._parseError = parseError
        self._diagramBounds = diagramBounds
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        context.coordinator.bind(view: view, parseError: $parseError, diagramBounds: $diagramBounds)
        return view
    }

    public func updateUIView(_ view: MermaidView, context: Context) {
        if view.theme != theme {
            view.theme = theme
        }
        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
        if view.source != source {
            view.source = source
        }
        context.coordinator.rebind(parseError: $parseError, diagramBounds: $diagramBounds)
    }
}

#elseif canImport(AppKit)
import AppKit

/// A SwiftUI view that renders a Mermaid diagram.
@available(macOS 13.0, *)
public struct MermaidDiagramView: NSViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self._parseError = parseError
        self._diagramBounds = diagramBounds
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        context.coordinator.bind(view: view, parseError: $parseError, diagramBounds: $diagramBounds)
        return view
    }

    public func updateNSView(_ view: MermaidView, context: Context) {
        if view.theme != theme {
            view.theme = theme
        }
        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
        if view.source != source {
            view.source = source
        }
        context.coordinator.rebind(parseError: $parseError, diagramBounds: $diagramBounds)
    }
}

#endif

#if canImport(UIKit) || canImport(AppKit)
extension MermaidDiagramView {
    /// Pushes preparation state (parse errors, diagram geometry) into the
    /// SwiftUI bindings when — and only when — it actually changes.
    ///
    /// The previous wrapper wrote both bindings on every `update…View` cycle,
    /// which re-invalidated ancestor views each pass, and it *polled*: state
    /// arriving from the background preparation queue between update cycles
    /// was not published until some unrelated update happened to run. This
    /// coordinator is event-driven via `MermaidView.onStateChange` instead.
    public final class Coordinator {
        private var parseError: Binding<Error?>?
        private var diagramBounds: Binding<CGRect>?
        private var lastBounds: CGRect = .null
        private var lastHadError: Bool?

        func bind(view: MermaidView, parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            view.onStateChange = { [weak self] error, bounds in
                self?.push(error: error, bounds: bounds)
            }
        }

        func rebind(parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
        }

        private func push(error: Error?, bounds: CGRect) {
            let hadError = error != nil
            let boundsChanged = bounds != lastBounds
            let errorChanged = hadError != lastHadError
            guard boundsChanged || errorChanged else { return }
            lastBounds = bounds
            lastHadError = hadError

            // Never mutate SwiftUI state from inside a view update pass; the
            // preparation callback can fire synchronously for empty sources.
            DispatchQueue.main.async { [self] in
                if errorChanged { parseError?.wrappedValue = error }
                if boundsChanged { diagramBounds?.wrappedValue = bounds }
            }
        }
    }
}
#endif
