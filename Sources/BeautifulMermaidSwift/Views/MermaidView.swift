import Foundation
import CoreGraphics
import QuartzCore

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

/// A UIView that renders Mermaid diagrams.
///
/// Rendering happens off the main thread: parse/layout runs on a background
/// queue (`MermaidLayer`), and the diagram is rasterized there too, then
/// composited by Core Animation via `layer.contents`. The main thread never
/// replays the vector command stream (which costs 3.9–19 ms per invalidation
/// for an 80-node diagram); its per-update share is an image assignment.
public class MermaidView: UIView {

    public let mermaidLayer: MermaidLayer

    public var source: String {
        get { mermaidLayer.source }
        set { mermaidLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { mermaidLayer.theme }
        set {
            mermaidLayer.theme = newValue
            backgroundColor = newValue.background
            updateContents()
        }
    }

    public var layoutConfig: LayoutConfig {
        get { mermaidLayer.layoutConfig }
        set { mermaidLayer.layoutConfig = newValue }
    }

    public var parseError: Error? { mermaidLayer.parseError }
    public var diagramBounds: CGRect { mermaidLayer.diagramBounds }

    /// Invoked on the main thread whenever preparation state changes
    /// (geometry published or a parse error surfaced). SwiftUI wrappers use
    /// this instead of polling on every update cycle.
    public var onStateChange: ((Error?, CGRect) -> Void)?

    public override init(frame: CGRect) {
        self.mermaidLayer = MermaidLayer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.mermaidLayer = MermaidLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = mermaidLayer.theme.background
        // The rasterized diagram is aspect-fitted and centered by Core
        // Animation; interim resizes GPU-scale the existing image and a
        // crisp re-raster follows at the new size.
        layer.contentsGravity = .resizeAspect
        // The internal hook, NOT `onPrepareComplete`: consumers replace the
        // public hook (it's a documented extension point), and when the view's
        // pipeline lived there such a replacement silently disconnected
        // contents updates — recycled cells came back blank.
        mermaidLayer.onPrepareCompleteForView = { [weak self] in
            guard let self else { return }
            self.invalidateIntrinsicContentSize()
            self.contentsDidChange()
            self.onStateChange?(self.parseError, self.diagramBounds)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateContents()
    }

    public override var intrinsicContentSize: CGSize {
        diagramBounds.size
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let db = diagramBounds
        guard db.width > 0, db.height > 0 else {
            return super.sizeThatFits(size)
        }
        let fitScale = min(size.width / db.width, size.height / db.height)
        return CGSize(width: db.width * fitScale, height: db.height * fitScale)
    }

    private func contentsDidChange() {
        if mermaidLayer.preparedDiagram == nil {
            layer.contents = nil
            return
        }
        updateContents()
    }

    private func updateContents() {
        let db = diagramBounds
        let viewBounds = bounds
        guard mermaidLayer.preparedDiagram != nil,
              db.width > 0, db.height > 0,
              viewBounds.width > 0, viewBounds.height > 0 else { return }

        let fitScale = min(viewBounds.width / db.width, viewBounds.height / db.height)
        let deviceScale = window?.screen.scale ?? UIScreen.main.scale
        let pixelSize = CGSize(
            width: db.width * fitScale * deviceScale,
            height: db.height * fitScale * deviceScale)

        mermaidLayer.requestRaster(pixelSize: pixelSize) { [weak self] image in
            guard let self else { return }
            self.layer.contentsScale = deviceScale
            self.layer.contents = image
        }
    }
}

#elseif canImport(AppKit)
import AppKit

/// An NSView that renders Mermaid diagrams.
///
/// Rendering happens off the main thread: parse/layout runs on a background
/// queue (`MermaidLayer`), and the diagram is rasterized there too, then
/// composited by Core Animation via `layer.contents`. The main thread never
/// replays the vector command stream (which costs 3.9–19 ms per invalidation
/// for an 80-node diagram); its per-update share is an image assignment.
/// During live window resize the existing raster is GPU-stretched and a crisp
/// re-raster follows on settle.
public class MermaidView: NSView {

    public let mermaidLayer: MermaidLayer

    public var source: String {
        get { mermaidLayer.source }
        set { mermaidLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { mermaidLayer.theme }
        set {
            mermaidLayer.theme = newValue
            layer?.backgroundColor = newValue.background.cgColor
            updateContents()
        }
    }

    public var layoutConfig: LayoutConfig {
        get { mermaidLayer.layoutConfig }
        set { mermaidLayer.layoutConfig = newValue }
    }

    public var parseError: Error? { mermaidLayer.parseError }
    public var diagramBounds: CGRect { mermaidLayer.diagramBounds }

    /// Invoked on the main thread whenever preparation state changes
    /// (geometry published or a parse error surfaced). SwiftUI wrappers use
    /// this instead of polling on every update cycle.
    public var onStateChange: ((Error?, CGRect) -> Void)?

    public override init(frame frameRect: NSRect) {
        self.mermaidLayer = MermaidLayer()
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.mermaidLayer = MermaidLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .resizeAspect
        layer?.backgroundColor = mermaidLayer.theme.background.cgColor
        // The internal hook, NOT `onPrepareComplete`: consumers replace the
        // public hook (it's a documented extension point), and when the view's
        // pipeline lived there such a replacement silently disconnected
        // contents updates — recycled cells came back blank.
        mermaidLayer.onPrepareCompleteForView = { [weak self] in
            guard let self else { return }
            self.invalidateIntrinsicContentSize()
            self.contentsDidChange()
            self.onStateChange?(self.parseError, self.diagramBounds)
        }
    }

    public override func layout() {
        super.layout()
        if !inLiveResize {
            updateContents()
        }
    }

    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateContents()
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: diagramBounds.width, height: diagramBounds.height)
    }

    private func contentsDidChange() {
        if mermaidLayer.preparedDiagram == nil {
            layer?.contents = nil
            return
        }
        updateContents()
    }

    private func updateContents() {
        let db = diagramBounds
        let viewBounds = bounds
        guard mermaidLayer.preparedDiagram != nil,
              db.width > 0, db.height > 0,
              viewBounds.width > 0, viewBounds.height > 0 else { return }

        let fitScale = min(viewBounds.width / db.width, viewBounds.height / db.height)
        let deviceScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelSize = CGSize(
            width: db.width * fitScale * deviceScale,
            height: db.height * fitScale * deviceScale)

        mermaidLayer.requestRaster(pixelSize: pixelSize) { [weak self] image in
            guard let self else { return }
            self.layer?.contentsScale = deviceScale
            self.layer?.contents = image
        }
    }
}

#endif
