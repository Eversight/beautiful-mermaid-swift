import Foundation
import CoreGraphics
import QuartzCore

#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A prepared diagram ready for direct CGContext rendering
public struct PreparedDiagram {
    /// The bounds of the diagram content
    public let bounds: CGRect
    /// Renders the diagram into the given context. The context should already be
    /// set up with the correct coordinate system (y=0 at top).
    public let render: (CGContext, CGRect) -> Void
}

/// A CALayer subclass that manages the Mermaid diagram rendering pipeline:
/// parse → layout → draw, with staged invalidation so each input change does
/// only the work it actually requires:
///
/// - `source`        → parse + layout + draw (parse/layout on a background queue)
/// - `layoutConfig`  → layout + draw (reuses the parsed graph)
/// - `theme`         → draw only (colors are a render-time concern; changing
///                     them re-parsed and re-laid-out the whole diagram before,
///                     stalling the main thread ~26 ms on an 80-node graph)
public class MermaidLayer: CALayer {

    // MARK: - Public Properties

    public var source: String = "" {
        didSet {
            if source != oldValue { prepareAsync(.parse) }
        }
    }

    public var theme: DiagramTheme = .default {
        didSet { rebuildRenderClosure() }
    }

    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet { prepareAsync(.layout) }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    /// Called on the main thread after the diagram is prepared (parsed + laid
    /// out) or after preparation failed. Not called for theme-only changes,
    /// which affect drawing but not geometry.
    ///
    /// Consumers may freely replace this; the owning view's contents pipeline
    /// runs on a separate internal hook and cannot be disconnected by it.
    public var onPrepareComplete: (() -> Void)?

    /// Reserved for the owning `MermaidView`'s contents pipeline; fired before
    /// `onPrepareComplete`. Kept separate from the public hook because
    /// consumers replacing `onPrepareComplete` used to silently disconnect the
    /// view from its own layer — a recycled cell that cleared and re-set
    /// `source` then never repopulated `layer.contents` and stayed blank.
    package var onPrepareCompleteForView: (() -> Void)?

    // MARK: - Pipeline state

    private enum PrepareStage {
        case parse   // source changed: parse + layout
        case layout  // layout config changed: reuse parsed graph
    }

    /// The last successfully parsed graph (keyed by `source`).
    private var parsedGraph: MermaidGraph?
    /// The last successful layout (input to draw; theme-independent).
    private var positionedGraph: PositionedGraph?

    /// Shared bounded-width pool for parse/layout/raster work, so keystrokes
    /// never stall the main thread. One layer's work never blocks behind a
    /// whole document of other layers (a serial queue made typing latency
    /// during document open grow linearly with block count: 17/76/207 ms at
    /// 8/24/64 blocks). Width leaves headroom for the main thread and is
    /// capped: prepare tasks are ms-scale and CPU-bound, so more width than
    /// this only adds memory-bandwidth contention. Superseded runs are
    /// detected via `generation` and discarded; out-of-order completion is
    /// handled the same way, so ordering needs no serialization.
    private static let prepareQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "beautiful-mermaid.prepare"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = max(2, min(ProcessInfo.processInfo.activeProcessorCount - 2, 8))
        return queue
    }()
    private var generation = 0

    // MARK: - Initialization

    public override init() {
        super.init()
        commonInit()
    }

    public override init(layer: Any) {
        if let other = layer as? MermaidLayer {
            super.init(layer: layer)
            self.source = other.source
            self.theme = other.theme
            self.layoutConfig = other.layoutConfig
            self.parseError = other.parseError
            self.diagramBounds = other.diagramBounds
            self.preparedDiagram = other.preparedDiagram
        } else {
            super.init(layer: layer)
        }
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        needsDisplayOnBoundsChange = true
        #if os(visionOS)
        contentsScale = 2.0
        #elseif targetEnvironment(macCatalyst) || canImport(UIKit)
        contentsScale = UIScreen.main.scale
        #elseif canImport(AppKit)
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        #endif
    }

    // MARK: - Bitmap Rendering

    public func renderImage(scale: CGFloat = 2.0) -> BMImage? {
        guard let prepared = preparedDiagram else { return nil }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let size = CGSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(ctx, diagBounds)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        // Flip for AppKit (lockFocus context has y=0 at bottom)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)

        prepared.render(ctx, diagBounds)

        image.unlockFocus()
        return image
        #endif
    }

    // MARK: - Private Methods

    /// Runs parse and/or layout off the main thread, then publishes the result
    /// back on main. A newer request supersedes older in-flight ones.
    private func prepareAsync(_ stage: PrepareStage) {
        generation += 1
        let expected = generation
        let source = self.source
        let layoutConfig = self.layoutConfig
        let reusableGraph = stage == .layout ? parsedGraph : nil

        guard !source.isEmpty else {
            parsedGraph = nil
            publish(generation: expected, result: nil)
            return
        }

        MermaidLayer.prepareQueue.addOperation { [weak self] in
            let result: Result<(MermaidGraph, PositionedGraph), Error>
            do {
                let graph = try reusableGraph ?? MermaidParser.parse(source)
                let positioned = try GraphLayout(config: layoutConfig).layout(graph)
                result = .success((graph, positioned))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                self?.publish(generation: expected, result: result)
            }
        }
    }

    /// Main-thread publication of a prepare result. Stale generations are dropped.
    private func publish(generation: Int, result: Result<(MermaidGraph, PositionedGraph), Error>?) {
        guard generation == self.generation else { return }

        switch result {
        case nil:
            parseError = nil
            positionedGraph = nil
            preparedDiagram = nil
            diagramBounds = .zero
            // Content changed to "nothing": bump so in-flight rasters of the
            // old diagram are dropped at delivery instead of resurrecting it.
            contentGeneration &+= 1
        case .failure(let error):
            parseError = error
            positionedGraph = nil
            preparedDiagram = nil
            diagramBounds = .zero
            contentGeneration &+= 1
        case .success(let (graph, positioned)):
            parseError = nil
            parsedGraph = graph
            positionedGraph = positioned
            diagramBounds = CGRect(x: 0, y: 0, width: max(1, positioned.width), height: max(1, positioned.height))
            rebuildRenderClosure()
        }

        setNeedsDisplay()
        onPrepareCompleteForView?()
        onPrepareComplete?()
    }

    /// Theme-only invalidation: rebuilds the draw closure around the existing
    /// geometry. No parsing, no layout, no main-thread stall.
    private func rebuildRenderClosure() {
        guard let positioned = positionedGraph else {
            contentGeneration &+= 1
            setNeedsDisplay()
            return
        }
        let renderer = DiagramRenderer(theme: theme)
        preparedDiagram = PreparedDiagram(bounds: diagramBounds) { context, renderBounds in
            renderer.render(positioned, in: context, bounds: renderBounds)
        }
        contentGeneration &+= 1
        setNeedsDisplay()
    }

    // MARK: - Async rasterization (the view contents pipeline)

    /// Bumped whenever drawable content changes (new preparation or theme).
    /// Raster deliveries are tagged with it so stale images are dropped.
    package private(set) var contentGeneration = 0

    /// Number of raster images actually delivered (test/diagnostic hook).
    package private(set) var rasterRenderCount = 0

    /// Monotonic id of the most recent accepted raster request. The prepare
    /// queue is concurrent, so completions can land out of order; only the
    /// newest request may deliver. Without this, an older smaller-size raster
    /// finishing late overwrote a newer crisp one and the view GPU-stretched
    /// the low-res image — the "sometimes blurry" bug.
    private var rasterSequence = 0
    /// The newest requested (content, pixel size) — dedups repeated layout
    /// passes asking for the state that is already in flight or on screen.
    private var lastRequestedKey: (generation: Int, width: Int, height: Int)?

    /// Rasterizes the prepared diagram at the given pixel size on the
    /// preparation queue and delivers the image on the main thread.
    ///
    /// This is the view pipeline's replacement for `draw(_:)`: the vector
    /// command stream costs 3.9–19 ms *on the main thread* per invalidation
    /// for an 80-node diagram (measured at view fit scales); rendering here
    /// and compositing via `layer.contents` reduces the main thread's share
    /// to an image assignment. Requests are coalesced per (content, pixel
    /// size); stale generations and duplicate sizes are dropped.
    package func requestRaster(
        pixelSize: CGSize,
        completion: @escaping (CGImage) -> Void
    ) {
        guard let prepared = preparedDiagram else { return }
        let bounds = prepared.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let width = Int(pixelSize.width.rounded()), height = Int(pixelSize.height.rounded())
        guard width > 0, height > 0 else { return }
        let key = (contentGeneration, width, height)
        // This exact content+size is already the newest desired state (in
        // flight or delivered) — nothing to do. Any *different* request resets
        // the sequence below, so an interleaved A→B→A correctly re-renders A.
        if let requested = lastRequestedKey, requested == key { return }
        lastRequestedKey = key
        rasterSequence &+= 1
        let sequence = rasterSequence

        MermaidLayer.prepareQueue.addOperation { [weak self] in
            var image: CGImage?
            let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            if let ctx = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info
            ) {
                // The raster holds only the diagram over a transparent background;
                // the view's layer background shows through, so transparent themes
                // need no special handling. Flip to the renderer's top-left origin.
                let scaleX = CGFloat(width) / bounds.width
                let scaleY = CGFloat(height) / bounds.height
                ctx.translateBy(x: 0, y: CGFloat(height))
                ctx.scaleBy(x: scaleX, y: -scaleY)
                ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
                prepared.render(ctx, bounds)
                image = ctx.makeImage()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                // Last-request-wins: deliver only if this is still the newest
                // request and the content hasn't changed since it was made.
                guard sequence == self.rasterSequence, key.0 == self.contentGeneration else { return }
                guard let image else {
                    // Bitmap creation failed; un-latch so a future pass retries.
                    self.lastRequestedKey = nil
                    return
                }
                self.rasterRenderCount += 1
                completion(image)
            }
        }
    }
}
