// Ported from original/src/ascii/draw.ts
import Foundation
import LayoutKernel

// ============================================================================
// Standalone grid→drawing coordinate conversion (for types-based AsciiGraph)
// ============================================================================

private func _gridToDrawingCoord(_ graph: AsciiGraph, _ c: GridCoord) -> DrawingCoord {
    var x = 0
    for col in 0..<c.x {
        x += graph.columnWidth[col] ?? 0
    }
    var y = 0
    for row in 0..<c.y {
        y += graph.rowHeight[row] ?? 0
    }
    let colW = graph.columnWidth[c.x] ?? 0
    let rowH = graph.rowHeight[c.y] ?? 0
    return DrawingCoord(
        x: x + (colW / 2) + graph.offsetX,
        y: y + (rowH / 2) + graph.offsetY
    )
}

private func _lineToDrawing(_ graph: AsciiGraph, _ line: [GridCoord]) -> [DrawingCoord] {
    line.map { _gridToDrawingCoord(graph, $0) }
}

private func _determineDrawingDirection(from: DrawingCoord, to: DrawingCoord) -> Direction {
    determineDirection(from: GridCoord(x: from.x, y: from.y), to: GridCoord(x: to.x, y: to.y))
}

// ============================================================================
// Node drawing — renders a node using shape-aware rendering
// ============================================================================

public func drawNode(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    drawBoxWithGridDimensions(node, graph)
}

private func drawBoxWithGridDimensions(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    guard let gc = node.gridCoord else {
        return mkCanvas(0, 0)
    }
    let useAscii = graph.config.useAscii

    // Width spans 2 columns (border + content)
    var w = 0
    for i in 0..<2 {
        w += graph.columnWidth[gc.x + i] ?? 0
    }
    // Height spans 2 rows (border + content)
    var h = 0
    for i in 0..<2 {
        h += graph.rowHeight[gc.y + i] ?? 0
    }

    var box = mkCanvas(max(0, w), max(0, h))

    // Get corner characters for this shape type
    let corners = getCorners(node.shape, useAscii)

    // State-end uses double border
    let isDoubleBox = node.shape == "state-end"
    let hChar: Character = useAscii ? (isDoubleBox ? "=" : "-") : (isDoubleBox ? "═" : "─")
    let vChar: Character = useAscii ? (isDoubleBox ? "‖" : "|") : (isDoubleBox ? "║" : "│")

    let doubleCorners = useAscii
        ? CornerChars(tl: "#", tr: "#", bl: "#", br: "#")
        : CornerChars(tl: "╔", tr: "╗", bl: "╚", br: "╝")
    let effectiveCorners = isDoubleBox ? doubleCorners : corners

    // Draw box border
    for x in 1..<w { box[x][0] = hChar }
    for x in 1..<w { box[x][h] = hChar }
    for y in 1..<h { box[0][y] = vChar }
    for y in 1..<h { box[w][y] = vChar }
    box[0][0] = effectiveCorners.tl
    box[w][0] = effectiveCorners.tr
    box[0][h] = effectiveCorners.bl
    box[w][h] = effectiveCorners.br

    // Center the multi-line display label inside the box
    let lines = splitLines(node.displayLabel)
    let textCenterY = Int(floor(Double(h) / 2.0))
    let startY = textCenterY - Int(floor(Double(lines.count - 1) / 2.0))

    for i in 0..<lines.count {
        let line = lines[i]
        let textX = Int(floor(Double(w) / 2.0)) - Int(ceil(Double(line.count) / 2.0)) + 1
        for (j, ch) in line.enumerated() {
            let px = textX + j
            let py = startY + i
            if px >= 0, px < box.count, py >= 0, py < (box[0].count) {
                box[px][py] = ch
            }
        }
    }

    return box
}

public func drawBox(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    drawNode(node, graph)
}

// ============================================================================
// Multi-section box drawing — for class and ER diagram nodes
// ============================================================================

public func drawMultiBox(_ sections: [[String]], _ useAscii: Bool, _ padding: Int = 1) -> Canvas {
    let maxTextWidth = sections.flatMap { $0 }.map { $0.count }.max() ?? 0
    let innerWidth = maxTextWidth + (2 * max(0, padding))
    let boxWidth = innerWidth + 2

    var totalLines = 0
    for section in sections {
        totalLines += max(1, section.count)
    }
    let dividerCount = max(0, sections.count - 1)
    let boxHeight = totalLines + dividerCount + 2

    let h: Character = useAscii ? "-" : "─"
    let v: Character = useAscii ? "|" : "│"
    let tl: Character = useAscii ? "+" : "┌"
    let tr: Character = useAscii ? "+" : "┐"
    let bl: Character = useAscii ? "+" : "└"
    let br: Character = useAscii ? "+" : "┘"
    let dl: Character = useAscii ? "+" : "├"
    let dr: Character = useAscii ? "+" : "┤"

    var canvas = mkCanvas(max(0, boxWidth - 1), max(0, boxHeight - 1))

    canvas[0][0] = tl
    canvas[boxWidth - 1][0] = tr
    canvas[0][boxHeight - 1] = bl
    canvas[boxWidth - 1][boxHeight - 1] = br

    for x in 1 ..< boxWidth - 1 {
        canvas[x][0] = h
        canvas[x][boxHeight - 1] = h
    }

    for y in 1 ..< boxHeight - 1 {
        canvas[0][y] = v
        canvas[boxWidth - 1][y] = v
    }

    var row = 1
    for s in 0 ..< sections.count {
        let section = sections[s].isEmpty ? [""] : sections[s]
        for line in section {
            let startX = 1 + max(0, padding)
            for (i, ch) in line.enumerated() where (startX + i) < (boxWidth - 1) {
                canvas[startX + i][row] = ch
            }
            row += 1
        }

        if s < sections.count - 1 {
            canvas[0][row] = dl
            canvas[boxWidth - 1][row] = dr
            for x in 1 ..< boxWidth - 1 {
                canvas[x][row] = h
            }
            row += 1
        }
    }

    return canvas
}

// ============================================================================
// Line drawing — 8-directional lines on the canvas
// ============================================================================

// ============================================================================
// Sparse edge-layer representation
//
// Each edge-drawing layer used to be materialized as a full W×H `copyCanvas`
// (blank, then a handful of cells set), and `drawGraph` merged ~7 of them per
// edge — the O(edges · W · H) super-linear ASCII cost. The draw producers now
// emit only the cells they touch (`[Cell]`), which `drawGraph` applies directly
// with the identical junction/first-alphanumeric/overwrite merge rule. Only the
// label layer can grow the canvas (`drawText` → `increaseSize`), so it stays a
// Canvas; every other layer is sparse. Output is byte-identical.
// ============================================================================

typealias Cell = (x: Int, y: Int, ch: Character)

/// Accumulates non-space cells with last-write-wins per (x, y) — matching the
/// `canvas[x][y] = ch` overwrite semantics the producers previously relied on.
private struct CellBuffer {
    let height: Int
    private(set) var cells: [Cell] = []
    private var indexByKey: [Int: Int] = [:]

    init(height: Int) { self.height = height }

    mutating func set(_ x: Int, _ y: Int, _ ch: Character) {
        let key = x &* height &+ y
        if let i = indexByKey[key] {
            cells[i].ch = ch
        } else {
            indexByKey[key] = cells.count
            cells.append((x, y, ch))
        }
    }
}

private func _isAlphanumericCell(_ c: Character) -> Bool {
    c.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
}

/// Extract the non-space cells of a Canvas in (x asc, y asc) order — used to fold
/// the (rare) bundled-edge canvases into the same sparse layer pipeline.
private func cellsFromCanvas(_ canvas: Canvas) -> [Cell] {
    var cells: [Cell] = []
    for x in 0 ..< canvas.count {
        let col = canvas[x]
        for y in 0 ..< col.count where col[y] != " " {
            cells.append((x, y, col[y]))
        }
    }
    return cells
}

/// Draw a line straight onto a Canvas (bundled-edge path drawing keeps canvases).
private func drawLineOnCanvas(
    _ canvas: inout Canvas,
    _ from: DrawingCoord,
    _ to: DrawingCoord,
    _ offsetFrom: Int,
    _ offsetTo: Int,
    _ useAscii: Bool,
    _ style: AsciiEdgeStyle = .solid
) -> [DrawingCoord] {
    let w = canvas.count
    let h = canvas.first?.count ?? 0
    return drawLine(from, to, offsetFrom, offsetTo, useAscii, style, boundsW: w, boundsH: h) { x, y, ch in
        canvas[x][y] = ch
    }
}

public func drawLine(
    _ from: DrawingCoord,
    _ to: DrawingCoord,
    _ offsetFrom: Int,
    _ offsetTo: Int,
    _ useAscii: Bool,
    _ style: AsciiEdgeStyle = .solid,
    boundsW: Int,
    boundsH: Int,
    plot: (Int, Int, Character) -> Void
) -> [DrawingCoord] {
    let dir = _determineDrawingDirection(from: from, to: to)
    var drawn: [DrawingCoord] = []

    let hChar: Character
    let vChar: Character

    switch style {
    case .dotted:
        hChar = useAscii ? "." : "┄"
        vChar = useAscii ? ":" : "┆"
    case .thick:
        hChar = useAscii ? "=" : "━"
        vChar = useAscii ? "‖" : "┃"
    case .solid:
        hChar = useAscii ? "-" : "─"
        vChar = useAscii ? "|" : "│"
    }

    func safeSet(_ x: Int, _ y: Int, _ ch: Character) {
        if x >= 0, x < boundsW, y >= 0, y < boundsH {
            plot(x, y, ch)
            drawn.append(DrawingCoord(x: x, y: y))
        }
    }

    // Pure vertical: Up
    if dirEquals(dir, Up) {
        var y = from.y - offsetFrom
        while y >= to.y - offsetTo {
            safeSet(from.x, y, vChar)
            y -= 1
        }
    }
    // Pure vertical: Down
    else if dirEquals(dir, Down) {
        var y = from.y + offsetFrom
        while y <= to.y + offsetTo {
            safeSet(from.x, y, vChar)
            y += 1
        }
    }
    // Pure horizontal: Left
    else if dirEquals(dir, Left) {
        var x = from.x - offsetFrom
        while x >= to.x - offsetTo {
            safeSet(x, from.y, hChar)
            x -= 1
        }
    }
    // Pure horizontal: Right
    else if dirEquals(dir, Right) {
        var x = from.x + offsetFrom
        while x <= to.x + offsetTo {
            safeSet(x, from.y, hChar)
            x += 1
        }
    }
    // UpperLeft: horizontal left, then vertical up
    else if dirEquals(dir, UpperLeft) {
        var x = from.x - offsetFrom
        while x >= to.x {
            safeSet(x, from.y, hChar)
            x -= 1
        }
        var y = from.y - 1
        while y >= to.y - offsetTo {
            safeSet(to.x, y, vChar)
            y -= 1
        }
    }
    // UpperRight: horizontal right, then vertical up
    else if dirEquals(dir, UpperRight) {
        var x = from.x + offsetFrom
        while x <= to.x {
            safeSet(x, from.y, hChar)
            x += 1
        }
        var y = from.y - 1
        while y >= to.y - offsetTo {
            safeSet(to.x, y, vChar)
            y -= 1
        }
    }
    // LowerLeft: horizontal left, then vertical down
    else if dirEquals(dir, LowerLeft) {
        var x = from.x - offsetFrom
        while x >= to.x {
            safeSet(x, from.y, hChar)
            x -= 1
        }
        var y = from.y + 1
        while y <= to.y + offsetTo {
            safeSet(to.x, y, vChar)
            y += 1
        }
    }
    // LowerRight: if dx ≤ 1, straight vertical; else horizontal right then vertical down
    else if dirEquals(dir, LowerRight) {
        let dx = to.x - from.x
        if dx <= 1 {
            var y = from.y + offsetFrom
            while y <= to.y + offsetTo {
                safeSet(from.x, y, vChar)
                y += 1
            }
        } else {
            var x = from.x + offsetFrom
            while x <= to.x {
                safeSet(x, from.y, hChar)
                x += 1
            }
            var y = from.y + 1
            while y <= to.y + offsetTo {
                safeSet(to.x, y, vChar)
                y += 1
            }
        }
    }

    return drawn
}

// ============================================================================
// Arrow drawing — path, corners, arrowheads, box-start junctions, labels
// ============================================================================

private func reverseDirection(_ dir: Direction) -> Direction {
    if dirEquals(dir, Up) { return Down }
    if dirEquals(dir, Down) { return Up }
    if dirEquals(dir, Left) { return Right }
    if dirEquals(dir, Right) { return Left }
    if dirEquals(dir, UpperLeft) { return LowerRight }
    if dirEquals(dir, UpperRight) { return LowerLeft }
    if dirEquals(dir, LowerLeft) { return UpperRight }
    if dirEquals(dir, LowerRight) { return UpperLeft }
    return Middle
}

private func drawPath(
    _ graph: AsciiGraph,
    _ path: [GridCoord],
    _ style: AsciiEdgeStyle = .solid
) -> ([Cell], [[DrawingCoord]], [Direction]) {
    let boundsW = graph.canvas.count
    let boundsH = graph.canvas.first?.count ?? 0
    var buffer = CellBuffer(height: boundsH)
    var previousCoord = path[0]
    var linesDrawn: [[DrawingCoord]] = []
    var lineDirs: [Direction] = []

    for i in 1..<path.count {
        let nextCoord = path[i]
        let prevDC = _gridToDrawingCoord(graph, previousCoord)
        let nextDC = _gridToDrawingCoord(graph, nextCoord)

        if prevDC == nextDC {
            previousCoord = nextCoord
            continue
        }

        let dir = determineDirection(from: previousCoord, to: nextCoord)
        var segment = drawLine(prevDC, nextDC, 1, -1, graph.config.useAscii, style, boundsW: boundsW, boundsH: boundsH) { x, y, ch in
            buffer.set(x, y, ch)
        }
        if segment.isEmpty { segment.append(prevDC) }
        linesDrawn.append(segment)
        lineDirs.append(dir)
        previousCoord = nextCoord
    }

    return (buffer.cells, linesDrawn, lineDirs)
}

private func drawBoxStart(
    _ graph: AsciiGraph,
    _ path: [GridCoord],
    _ firstLine: [DrawingCoord],
    _ sourceShape: String
) -> [Cell] {
    if graph.config.useAscii { return [] }
    // Skip for state pseudo-states
    if sourceShape == "state-start" || sourceShape == "state-end" { return [] }

    guard !firstLine.isEmpty, path.count >= 2 else { return [] }
    let from = firstLine[0]
    let dir = determineDirection(from: path[0], to: path[1])
    let boundsW = graph.canvas.count
    let boundsH = graph.canvas.first?.count ?? 0

    func cell(_ x: Int, _ y: Int, _ ch: Character) -> [Cell] {
        (x >= 0 && x < boundsW && y >= 0 && y < boundsH) ? [(x, y, ch)] : []
    }

    if dirEquals(dir, Up) { return cell(from.x, from.y + 1, "┴") }
    if dirEquals(dir, Down) { return cell(from.x, from.y - 1, "┬") }
    if dirEquals(dir, Left) { return cell(from.x + 1, from.y, "┤") }
    if dirEquals(dir, Right) { return cell(from.x - 1, from.y, "├") }
    return []
}

private func drawArrowHead(
    _ graph: AsciiGraph,
    _ lastLine: [DrawingCoord],
    _ fallbackDir: Direction
) -> [Cell] {
    guard !lastLine.isEmpty else { return [] }

    let from = lastLine[0]
    let lastPos = lastLine[lastLine.count - 1]
    var dir = _determineDrawingDirection(from: from, to: lastPos)
    if lastLine.count == 1 || dirEquals(dir, Middle) { dir = fallbackDir }

    let ch: Character

    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else if dirEquals(dir, UpperRight) { ch = "◥" }
        else if dirEquals(dir, UpperLeft) { ch = "◤" }
        else if dirEquals(dir, LowerRight) { ch = "◢" }
        else if dirEquals(dir, LowerLeft) { ch = "◣" }
        else {
            if dirEquals(fallbackDir, Up) { ch = "▲" }
            else if dirEquals(fallbackDir, Down) { ch = "▼" }
            else if dirEquals(fallbackDir, Left) { ch = "◄" }
            else if dirEquals(fallbackDir, Right) { ch = "►" }
            else if dirEquals(fallbackDir, UpperRight) { ch = "◥" }
            else if dirEquals(fallbackDir, UpperLeft) { ch = "◤" }
            else if dirEquals(fallbackDir, LowerRight) { ch = "◢" }
            else if dirEquals(fallbackDir, LowerLeft) { ch = "◣" }
            else { ch = "●" }
        }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else {
            if dirEquals(fallbackDir, Up) { ch = "^" }
            else if dirEquals(fallbackDir, Down) { ch = "v" }
            else if dirEquals(fallbackDir, Left) { ch = "<" }
            else if dirEquals(fallbackDir, Right) { ch = ">" }
            else { ch = "*" }
        }
    }

    let boundsW = graph.canvas.count
    let boundsH = graph.canvas.first?.count ?? 0
    if lastPos.x >= 0, lastPos.x < boundsW, lastPos.y >= 0, lastPos.y < boundsH {
        return [(lastPos.x, lastPos.y, ch)]
    }
    return []
}

private func drawCorners(_ graph: AsciiGraph, _ path: [GridCoord]) -> [Cell] {
    let boundsW = graph.canvas.count
    let boundsH = graph.canvas.first?.count ?? 0
    var buffer = CellBuffer(height: boundsH)

    for idx in 1..<(path.count - 1) {
        let coord = path[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: path[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: path[idx + 1])

        let corner: Character
        if !graph.config.useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) {
                corner = "┐"
            } else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                        (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) {
                corner = "┘"
            } else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                        (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) {
                corner = "┌"
            } else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                        (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) {
                corner = "└"
            } else {
                corner = "+"
            }
        } else {
            corner = "+"
        }

        if dc.x >= 0, dc.x < boundsW, dc.y >= 0, dc.y < boundsH {
            buffer.set(dc.x, dc.y, corner)
        }
    }

    return buffer.cells
}

private func drawTextOnLine(_ canvas: inout Canvas, _ line: [DrawingCoord], _ label: String, _ isUpwardEdge: Bool?) {
    guard line.count >= 2 else { return }
    let minX = min(line[0].x, line[1].x)
    let maxX = max(line[0].x, line[1].x)
    let minY = min(line[0].y, line[1].y)
    let maxY = max(line[0].y, line[1].y)
    let middleX = minX + Int(floor(Double(maxX - minX) / 2.0))
    var middleY = minY + Int(floor(Double(maxY - minY) / 2.0))

    // Offset label vertically on bidirectional edges
    if let isUpward = isUpwardEdge, minX == maxX {
        let segmentHeight = maxY - minY
        let offset = max(1, Int(floor(Double(segmentHeight) / 4.0)))
        middleY += isUpward ? offset : -offset
    }

    let lines = splitLines(label)
    let startY = middleY - Int(floor(Double(lines.count - 1) / 2.0))

    for (i, lineText) in lines.enumerated() {
        let startX = middleX - Int(floor(Double(lineText.count) / 2.0))
        drawText(&canvas, start: DrawingCoord(x: startX, y: startY + i), text: lineText)
    }
}

private func drawArrowLabel(_ graph: AsciiGraph, _ edge: AsciiEdge) -> Canvas? {
    // No label → no canvas. Previously this returned a full blank `copyCanvas`,
    // which `drawGraph` then allocated + scanned per edge (O(edges · W · H) for the
    // overwhelmingly common label-free edge). Return nil and skip it.
    if edge.text.isEmpty { return nil }
    var canvas = copyCanvas(graph.canvas)

    let drawingLine = _lineToDrawing(graph, edge.labelLine)

    var isUpwardEdge: Bool?
    if edge.path.count >= 2 {
        let startY = edge.path[0].y
        let endY = edge.path[edge.path.count - 1].y
        if endY < startY { isUpwardEdge = true }
        else if endY > startY { isUpwardEdge = false }
    }

    drawTextOnLine(&canvas, drawingLine, edge.text, isUpwardEdge)
    return canvas
}

func drawArrow(_ graph: AsciiGraph, _ edge: AsciiEdge) -> ([Cell], [Cell], [Cell], [Cell], [Cell], Canvas?) {
    if edge.path.isEmpty {
        return ([], [], [], [], [], nil)
    }

    let labelCanvas = drawArrowLabel(graph, edge)
    let (pathCells, linesDrawn, lineDirs) = drawPath(graph, edge.path, edge.style)

    let boxStartCells: [Cell] = linesDrawn.isEmpty
        ? []
        : drawBoxStart(graph, edge.path, linesDrawn[0], edge.from.shape)

    // End arrowhead
    let arrowHeadEndCells: [Cell]
    if edge.hasArrowEnd, !linesDrawn.isEmpty, !lineDirs.isEmpty {
        arrowHeadEndCells = drawArrowHead(
            graph,
            linesDrawn[linesDrawn.count - 1],
            lineDirs[lineDirs.count - 1]
        )
    } else {
        arrowHeadEndCells = []
    }

    // Start arrowhead (bidirectional)
    let arrowHeadStartCells: [Cell]
    if edge.hasArrowStart, !linesDrawn.isEmpty, !lineDirs.isEmpty {
        let firstLine = linesDrawn[0]
        let firstPoint = firstLine[0]
        let startDir = reverseDirection(lineDirs[0])

        var arrowPos = DrawingCoord(x: firstPoint.x, y: firstPoint.y)
        if dirEquals(lineDirs[0], Right) { arrowPos.x = firstPoint.x - 1 }
        else if dirEquals(lineDirs[0], Left) { arrowPos.x = firstPoint.x + 1 }
        else if dirEquals(lineDirs[0], Down) { arrowPos.y = firstPoint.y - 1 }
        else if dirEquals(lineDirs[0], Up) { arrowPos.y = firstPoint.y + 1 }

        let syntheticLine = [firstPoint, arrowPos]
        arrowHeadStartCells = drawArrowHead(graph, syntheticLine, startDir)
    } else {
        arrowHeadStartCells = []
    }

    let cornersCells = drawCorners(graph, edge.path)

    return (pathCells, boxStartCells, arrowHeadEndCells, arrowHeadStartCells, cornersCells, labelCanvas)
}

// ============================================================================
// Node attachment point helper
// ============================================================================

private func getNodeAttachmentPoint(
    _ graph: AsciiGraph,
    _ node: AsciiNode,
    _ dir: Direction
) -> DrawingCoord {
    guard let gc = node.gridCoord, let baseCoord = node.drawingCoord else {
        return DrawingCoord(x: 0, y: 0)
    }

    var w = 0
    for i in 0..<2 { w += graph.columnWidth[gc.x + i] ?? 0 }
    var h = 0
    for i in 0..<2 { h += graph.rowHeight[gc.y + i] ?? 0 }

    let gridDimensions = ShapeDimensions(
        width: w + 1,
        height: h + 1,
        labelArea: ShapeLabelArea(x: 0, y: 0, width: 0, height: 0),
        gridColumns: [0, 0, 0],
        gridRows: [0, 0, 0]
    )

    return getShapeAttachmentPoint(node.shape, dir, gridDimensions, baseCoord)
}

// ============================================================================
// Bundled edge drawing
// ============================================================================

private func drawBundledEdgeSegment(
    _ graph: AsciiGraph,
    _ edge: AsciiEdge,
    _ bundle: EdgeBundle
) -> (Canvas, Canvas, Canvas, Canvas, Canvas, Canvas) {
    let empty = copyCanvas(graph.canvas)

    guard let pathToJunction = edge.pathToJunction, !pathToJunction.isEmpty else {
        return (empty, empty, empty, empty, empty, empty)
    }

    var pathCanvas = copyCanvas(graph.canvas)
    let useAscii = graph.config.useAscii

    let drawingPath: [DrawingCoord] = pathToJunction.enumerated().map { idx, gc in
        if bundle.type == "fan-in" && idx == 0 {
            return getNodeAttachmentPoint(graph, edge.from, edge.startDir)
        }
        if bundle.type == "fan-out" && idx == pathToJunction.count - 1 {
            return getNodeAttachmentPoint(graph, edge.to, edge.endDir)
        }
        return _gridToDrawingCoord(graph, gc)
    }

    for i in 1..<drawingPath.count {
        let from = drawingPath[i - 1]
        let to = drawingPath[i]
        if from != to {
            _ = drawLineOnCanvas(&pathCanvas, from, to, 1, -1, useAscii, edge.style)
        }
    }

    // Corners at path bends
    var cornersCanvas = copyCanvas(graph.canvas)
    for idx in 1..<(pathToJunction.count - 1) {
        let coord = pathToJunction[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: pathToJunction[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: pathToJunction[idx + 1])

        let corner: Character
        if !useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) { corner = "┐" }
            else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) { corner = "┘" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                      (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) { corner = "┌" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) { corner = "└" }
            else { corner = "+" }
        } else { corner = "+" }

        if dc.x >= 0, dc.x < cornersCanvas.count, dc.y >= 0, dc.y < (cornersCanvas.first?.count ?? 0) {
            cornersCanvas[dc.x][dc.y] = corner
        }
    }

    // Box start connector (fan-in, from source node)
    var boxStartCanvas = copyCanvas(graph.canvas)
    if bundle.type == "fan-in", pathToJunction.count >= 2 {
        let firstPoint = drawingPath[0]
        let dir = determineDirection(from: pathToJunction[0], to: pathToJunction[1])
        if !useAscii {
            func safeSet(_ x: Int, _ y: Int, _ ch: Character) {
                if x >= 0, x < boxStartCanvas.count, y >= 0, y < (boxStartCanvas.first?.count ?? 0) {
                    boxStartCanvas[x][y] = ch
                }
            }
            if dirEquals(dir, Up) { safeSet(firstPoint.x, firstPoint.y, "┴") }
            else if dirEquals(dir, Down) { safeSet(firstPoint.x, firstPoint.y, "┬") }
            else if dirEquals(dir, Left) { safeSet(firstPoint.x, firstPoint.y, "┤") }
            else if dirEquals(dir, Right) { safeSet(firstPoint.x, firstPoint.y, "├") }
        }
    }

    let labelCanvas = copyCanvas(graph.canvas)
    return (pathCanvas, boxStartCanvas, empty, empty, cornersCanvas, labelCanvas)
}

private func drawBundleSharedPath(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> (Canvas, Canvas) {
    var pathCanvas = copyCanvas(graph.canvas)
    var cornersCanvas = copyCanvas(graph.canvas)

    guard bundle.sharedPath.count >= 2 else {
        return (pathCanvas, cornersCanvas)
    }

    let useAscii = graph.config.useAscii
    let style = bundle.edges.first?.style ?? .solid
    let graphDir = graph.config.graphDirection

    let drawingPath: [DrawingCoord] = bundle.sharedPath.enumerated().map { idx, gc in
        if bundle.type == "fan-in" && idx == bundle.sharedPath.count - 1 {
            let entryDir = graphDir == "TD" ? Up : Left
            return getNodeAttachmentPoint(graph, bundle.sharedNode, entryDir)
        }
        if bundle.type == "fan-out" && idx == 0 {
            let exitDir = graphDir == "TD" ? Down : Right
            return getNodeAttachmentPoint(graph, bundle.sharedNode, exitDir)
        }
        return _gridToDrawingCoord(graph, gc)
    }

    for i in 1..<drawingPath.count {
        let from = drawingPath[i - 1]
        let to = drawingPath[i]
        if from != to {
            _ = drawLineOnCanvas(&pathCanvas, from, to, 1, -1, useAscii, style)
        }
    }

    for idx in 1..<(bundle.sharedPath.count - 1) {
        let coord = bundle.sharedPath[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: bundle.sharedPath[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: bundle.sharedPath[idx + 1])

        let corner: Character
        if !useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) { corner = "┐" }
            else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) { corner = "┘" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                      (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) { corner = "┌" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) { corner = "└" }
            else { corner = "+" }
        } else { corner = "+" }

        if dc.x >= 0, dc.x < cornersCanvas.count, dc.y >= 0, dc.y < (cornersCanvas.first?.count ?? 0) {
            cornersCanvas[dc.x][dc.y] = corner
        }
    }

    return (pathCanvas, cornersCanvas)
}

private func drawBundleArrowhead(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard bundle.sharedPath.count >= 2 else { return canvas }

    let lastIdx = bundle.sharedPath.count - 1
    let dir = determineDirection(from: bundle.sharedPath[lastIdx - 1], to: bundle.sharedPath[lastIdx])

    let graphDir = graph.config.graphDirection
    let entryDir = graphDir == "TD" ? Up : Left
    var dc = getNodeAttachmentPoint(graph, bundle.sharedNode, entryDir)
    if graphDir == "TD" { dc.y -= 1 } else { dc.x -= 1 }

    let ch: Character
    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else { ch = "▼" }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else { ch = "v" }
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}

private func drawBundledEdgeArrowhead(_ graph: AsciiGraph, _ edge: AsciiEdge) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard let pathToJunction = edge.pathToJunction, pathToJunction.count >= 2 else { return canvas }

    let lastIdx = pathToJunction.count - 1
    let dir = determineDirection(from: pathToJunction[lastIdx - 1], to: pathToJunction[lastIdx])

    let graphDir = graph.config.graphDirection
    let entryDir = graphDir == "TD" ? Up : Left
    var dc = getNodeAttachmentPoint(graph, edge.to, entryDir)
    if graphDir == "TD" { dc.y -= 1 } else { dc.x -= 1 }

    let ch: Character
    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else { ch = "▼" }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else { ch = "v" }
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}

private func drawJunctionCharacter(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard let junctionPoint = bundle.junctionPoint else { return canvas }

    let dc = _gridToDrawingCoord(graph, junctionPoint)
    let useAscii = graph.config.useAscii

    var hasUp = false, hasDown = false, hasLeft = false, hasRight = false

    if bundle.sharedPath.count >= 2 {
        let junctionIdx = bundle.type == "fan-in" ? 0 : bundle.sharedPath.count - 1
        let adjacentIdx = bundle.type == "fan-in" ? 1 : bundle.sharedPath.count - 2
        let sharedDir = determineDirection(from: bundle.sharedPath[junctionIdx], to: bundle.sharedPath[adjacentIdx])
        if dirEquals(sharedDir, Down) { hasDown = true }
        else if dirEquals(sharedDir, Up) { hasUp = true }
        else if dirEquals(sharedDir, Right) { hasRight = true }
        else if dirEquals(sharedDir, Left) { hasLeft = true }
    }

    for edge in bundle.edges {
        guard let pathToJunction = edge.pathToJunction, pathToJunction.count >= 2 else { continue }
        let junctionIdx = bundle.type == "fan-in" ? pathToJunction.count - 1 : 0
        let adjacentIdx = bundle.type == "fan-in" ? pathToJunction.count - 2 : 1
        let arrivalDir = determineDirection(from: pathToJunction[adjacentIdx], to: pathToJunction[junctionIdx])
        if dirEquals(arrivalDir, Down) { hasUp = true }
        else if dirEquals(arrivalDir, Up) { hasDown = true }
        else if dirEquals(arrivalDir, Right) { hasLeft = true }
        else if dirEquals(arrivalDir, Left) { hasRight = true }
    }

    let ch: Character
    if !useAscii {
        if hasUp && hasDown && hasLeft && hasRight { ch = "┼" }
        else if hasDown && hasLeft && hasRight && !hasUp { ch = "┬" }
        else if hasUp && hasLeft && hasRight && !hasDown { ch = "┴" }
        else if hasUp && hasDown && hasRight && !hasLeft { ch = "├" }
        else if hasUp && hasDown && hasLeft && !hasRight { ch = "┤" }
        else if hasLeft && hasRight { ch = "─" }
        else if hasUp && hasDown { ch = "│" }
        else if hasDown && hasRight { ch = "┌" }
        else if hasDown && hasLeft { ch = "┐" }
        else if hasUp && hasRight { ch = "└" }
        else if hasUp && hasLeft { ch = "┘" }
        else { ch = "┼" }
    } else {
        ch = "+"
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}

// ============================================================================
// Subgraph drawing
// ============================================================================

public func drawSubgraphBox(_ sg: AsciiSubgraph, _ graph: AsciiGraph) -> Canvas {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return mkCanvas(0, 0) }

    var canvas = mkCanvas(width, height)

    if !graph.config.useAscii {
        for x in 1..<width { canvas[x][0] = "─" }
        for x in 1..<width { canvas[x][height] = "─" }
        for y in 1..<height { canvas[0][y] = "│" }
        for y in 1..<height { canvas[width][y] = "│" }
        canvas[0][0] = "┌"
        canvas[width][0] = "┐"
        canvas[0][height] = "└"
        canvas[width][height] = "┘"
    } else {
        for x in 1..<width { canvas[x][0] = "-" }
        for x in 1..<width { canvas[x][height] = "-" }
        for y in 1..<height { canvas[0][y] = "|" }
        for y in 1..<height { canvas[width][y] = "|" }
        canvas[0][0] = "+"
        canvas[width][0] = "+"
        canvas[0][height] = "+"
        canvas[width][height] = "+"
    }

    return canvas
}

public func drawSubgraphLabel(_ sg: AsciiSubgraph, _ graph: AsciiGraph) -> (Canvas, DrawingCoord) {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return (mkCanvas(0, 0), DrawingCoord(x: 0, y: 0)) }

    var canvas = mkCanvas(width, height)

    let lines = splitLines(sg.name)
    for (i, line) in lines.enumerated() {
        let labelY = 1 + i
        var labelX = Int(floor(Double(width) / 2.0)) - Int(floor(Double(line.count) / 2.0))
        if labelX < 1 { labelX = 1 }

        for (j, ch) in line.enumerated() {
            if labelX + j < width, labelY < height {
                canvas[labelX + j][labelY] = ch
            }
        }
    }

    return (canvas, DrawingCoord(x: sg.minX, y: sg.minY))
}

// ============================================================================
// Role tracking helpers
// ============================================================================

private func fillRolesFromCanvas(
    _ roleCanvas: inout RoleCanvas,
    _ canvas: Canvas,
    _ offset: DrawingCoord,
    _ role: CharRole
) {
    for x in 0..<canvas.count {
        for y in 0..<(canvas[0].count) {
            let ch = canvas[x][y]
            if ch != " " {
                let rx = x + offset.x
                let ry = y + offset.y
                if rx >= 0, ry >= 0 {
                    setRole(&roleCanvas, rx, ry, role)
                }
            }
        }
    }
}

private func fillRolesFromCanvases(
    _ roleCanvas: inout RoleCanvas,
    _ canvases: [Canvas],
    _ offset: DrawingCoord,
    _ role: CharRole
) {
    for canvas in canvases {
        fillRolesFromCanvas(&roleCanvas, canvas, offset, role)
    }
}

private let _borderChars: Set<Character> = [
    "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─",
    "╭", "╮", "╰", "╯", "+", "-", "|", "'", ":", ".",
    "╟", "╢", "╔", "╗", "╚", "╝", "═", "║",
    "◯", "◎", "◇", "⌜", "⌝", "⌞", "⌟", "(", ")", "●", "◉",
    "▷", "/", "\\",
]

private func fillRolesForNodeBox(
    _ roleCanvas: inout RoleCanvas,
    _ canvas: Canvas,
    _ offset: DrawingCoord
) {
    for x in 0..<canvas.count {
        for y in 0..<(canvas[0].count) {
            let ch = canvas[x][y]
            if ch != " " {
                let rx = x + offset.x
                let ry = y + offset.y
                if rx >= 0, ry >= 0 {
                    setRole(&roleCanvas, rx, ry, _borderChars.contains(ch) ? .border : .text)
                }
            }
        }
    }
}

// ============================================================================
// In-place canvas application (replaces per-node `mergeCanvases`)
// ============================================================================

/// Apply one overlay's chars onto `canvas` at `offset` in place — byte-identical
/// to `graph.canvas = mergeCanvases(graph.canvas, offset, useAscii, overlay)` but
/// without allocating and recopying the whole canvas. Grows only when the overlay
/// genuinely extends past the current bounds (node boxes / subgraph boxes sit
/// inside the canvas, so the common case is a pure in-place write). Roles are left
/// to the caller's existing `fillRoles*` call, unchanged.
private func applyCanvasCharsInPlace(
    _ canvas: inout Canvas,
    _ overlay: Canvas,
    _ offset: DrawingCoord,
    _ useAscii: Bool
) {
    let (oX, oY) = getCanvasSize(overlay)
    let (bX, bY) = getCanvasSize(canvas)
    let targetX = max(bX, oX + offset.x)
    let targetY = max(bY, oY + offset.y)
    if targetX > bX || targetY > bY {
        _ = increaseSize(&canvas, targetX, targetY)
    }

    let w = canvas.count
    let h = canvas.first?.count ?? 0
    for x in 0 ..< overlay.count {
        let mx = x + offset.x
        if mx < 0 || mx >= w { continue }
        let col = overlay[x]
        for y in 0 ..< col.count {
            let c = col[y]
            if c == " " { continue }
            let my = y + offset.y
            if my < 0 || my >= h { continue }
            let current = canvas[mx][my]
            if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                canvas[mx][my] = mergeJunctions(current, c)
            } else if _isAlphanumericCell(current) && _isAlphanumericCell(c) {
                // preserve first-written label text
            } else {
                canvas[mx][my] = c
            }
        }
    }
}

// ============================================================================
// Sparse layer application (replaces mergeCanvasArray + fillRolesFromCanvases)
// ============================================================================

/// Apply a sparse edge layer directly onto the canvas + role canvas. Chars use
/// the identical junction / first-alphanumeric / overwrite rule as `mergeCanvases`,
/// applied in edge order; the role is set for every drawn cell (last-layer-wins,
/// decoupled from the char-merge outcome — matching `fillRolesFromCanvases`).
/// The canvas/roleCanvas are assumed already grown to the final size.
private func applyCellLayer(
    _ canvas: inout Canvas,
    _ roleCanvas: inout RoleCanvas,
    _ perEdge: [[Cell]],
    _ useAscii: Bool,
    _ role: CharRole
) {
    let w = canvas.count
    let h = canvas.first?.count ?? 0
    let rw = roleCanvas.count
    let rh = roleCanvas.first?.count ?? 0
    for cells in perEdge {
        for cell in cells {
            let x = cell.x
            let y = cell.y
            if x < 0 || x >= w || y < 0 || y >= h { continue }
            let c = cell.ch
            let current = canvas[x][y]
            if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                canvas[x][y] = mergeJunctions(current, c)
            } else if _isAlphanumericCell(current) && _isAlphanumericCell(c) {
                // preserve first-written label text
            } else {
                canvas[x][y] = c
            }
            if x < rw, y < rh {
                roleCanvas[x][y] = role
            }
        }
    }
}

/// The label layer stays canvas-based (it can extend beyond the graph canvas via
/// `drawText`). Applied with the same rule + role `.text`; canvas already grown.
private func applyLabelLayer(
    _ canvas: inout Canvas,
    _ roleCanvas: inout RoleCanvas,
    _ labels: [Canvas],
    _ useAscii: Bool
) {
    let w = canvas.count
    let h = canvas.first?.count ?? 0
    let rw = roleCanvas.count
    let rh = roleCanvas.first?.count ?? 0
    for label in labels {
        for x in 0 ..< min(label.count, w) {
            let col = label[x]
            let n = min(col.count, h)
            for y in 0 ..< n {
                let c = col[y]
                if c == " " { continue }
                let current = canvas[x][y]
                if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                    canvas[x][y] = mergeJunctions(current, c)
                } else if _isAlphanumericCell(current) && _isAlphanumericCell(c) {
                    // preserve first-written label text
                } else {
                    canvas[x][y] = c
                }
                if x < rw, y < rh {
                    roleCanvas[x][y] = .text
                }
            }
        }
    }
}

// ============================================================================
// Sorting helper
// ============================================================================

private func sortSubgraphsByDepth(_ subgraphs: [AsciiSubgraph]) -> [AsciiSubgraph] {
    func getDepth(_ sg: AsciiSubgraph) -> Int {
        sg.parent == nil ? 0 : 1
    }
    return subgraphs.sorted { getDepth($0) < getDepth($1) }
}

// ============================================================================
// Top-level draw orchestrator
// ============================================================================

public func drawGraph(_ graph: inout AsciiGraph) -> Canvas {
    let useAscii = graph.config.useAscii

    // 1. Draw subgraph borders (bottom layer)
    let sortedSgs = sortSubgraphsByDepth(graph.subgraphs)
    for sg in sortedSgs {
        if sg.nodes.isEmpty { continue }
        let sgCanvas = drawSubgraphBox(sg, graph)
        let offset = DrawingCoord(x: sg.minX, y: sg.minY)
        applyCanvasCharsInPlace(&graph.canvas, sgCanvas, offset, useAscii)
        fillRolesFromCanvas(&graph.roleCanvas, sgCanvas, offset, .border)
    }

    // 2. Draw node boxes
    for i in 0..<graph.nodes.count {
        let node = graph.nodes[i]
        if !node.drawn, let dc = node.drawingCoord, let drawing = node.drawing {
            applyCanvasCharsInPlace(&graph.canvas, drawing, dc, useAscii)
            fillRolesForNodeBox(&graph.roleCanvas, drawing, dc)
            graph.nodes[i].drawn = true
        }
    }

    // 3. Collect all edge drawing layers as sparse cells. Labels stay canvases
    //    (the only layer that can grow the canvas, via drawText → increaseSize).
    var lineCells: [[Cell]] = []
    var cornerCells: [[Cell]] = []
    var arrowHeadEndCells: [[Cell]] = []
    var arrowHeadStartCells: [[Cell]] = []
    var boxStartCells: [[Cell]] = []
    var labelCanvases: [Canvas] = []
    var junctionCells: [[Cell]] = []

    var processedBundleTypes = Set<String>()

    for edge in graph.edges {
        if let bundle = edge.bundle, edge.pathToJunction != nil {
            // Bundled edges keep their canvas-based producers; fold to cells here.
            // Bundled edges never render a label (the label canvas is always
            // blank), so drop it — scanning a blank canvas is pure waste.
            let (pathC, boxStartC, _, _, cornersC, _) = drawBundledEdgeSegment(graph, edge, bundle)
            lineCells.append(cellsFromCanvas(pathC))
            cornerCells.append(cellsFromCanvas(cornersC))
            boxStartCells.append(cellsFromCanvas(boxStartC))

            let bundleKey = "\(bundle.type)-\(bundle.sharedNode.name)-\(bundle.sharedNode.index)"
            if !processedBundleTypes.contains(bundleKey) {
                processedBundleTypes.insert(bundleKey)

                let (sharedPathC, sharedCornersC) = drawBundleSharedPath(graph, bundle)
                lineCells.append(cellsFromCanvas(sharedPathC))
                cornerCells.append(cellsFromCanvas(sharedCornersC))

                if bundle.type == "fan-in" {
                    arrowHeadEndCells.append(cellsFromCanvas(drawBundleArrowhead(graph, bundle)))
                }

                junctionCells.append(cellsFromCanvas(drawJunctionCharacter(graph, bundle)))
            }

            if bundle.type == "fan-out", edge.hasArrowEnd {
                arrowHeadEndCells.append(cellsFromCanvas(drawBundledEdgeArrowhead(graph, edge)))
            }
        } else {
            let (pathC, boxStartC, arrowHeadEndC, arrowHeadStartC, cornersC, labelC) = drawArrow(graph, edge)
            lineCells.append(pathC)
            cornerCells.append(cornersC)
            arrowHeadEndCells.append(arrowHeadEndC)
            arrowHeadStartCells.append(arrowHeadStartC)
            boxStartCells.append(boxStartC)
            if let labelC { labelCanvases.append(labelC) }
        }
    }

    // 4. Grow the canvas + role canvas once to the final size (only the label
    //    layer can extend past the current canvas), then apply every layer in the
    //    original order. This replaces 7 × O(edges · W · H) canvas merges.
    var finalX = max(0, graph.canvas.count - 1)
    var finalY = max(0, (graph.canvas.first?.count ?? 1) - 1)
    for label in labelCanvases {
        finalX = max(finalX, max(0, label.count - 1))
        finalY = max(finalY, max(0, (label.first?.count ?? 1) - 1))
    }
    _ = increaseSize(&graph.canvas, finalX, finalY)
    _ = increaseRoleCanvasSize(&graph.roleCanvas, finalX, finalY)

    applyCellLayer(&graph.canvas, &graph.roleCanvas, lineCells, useAscii, .line)
    applyCellLayer(&graph.canvas, &graph.roleCanvas, cornerCells, useAscii, .corner)
    applyCellLayer(&graph.canvas, &graph.roleCanvas, junctionCells, useAscii, .junction)
    applyCellLayer(&graph.canvas, &graph.roleCanvas, arrowHeadEndCells, useAscii, .arrow)
    applyCellLayer(&graph.canvas, &graph.roleCanvas, boxStartCells, useAscii, .junction)
    applyCellLayer(&graph.canvas, &graph.roleCanvas, arrowHeadStartCells, useAscii, .arrow)
    applyLabelLayer(&graph.canvas, &graph.roleCanvas, labelCanvases, useAscii)

    // 5. Draw subgraph labels (top layer)
    for sg in graph.subgraphs {
        if sg.nodes.isEmpty { continue }
        let (labelCanvas, offset) = drawSubgraphLabel(sg, graph)
        applyCanvasCharsInPlace(&graph.canvas, labelCanvas, offset, useAscii)
        fillRolesFromCanvas(&graph.roleCanvas, labelCanvas, offset, .text)
    }

    return graph.canvas
}

public enum AsciiDraw {
}
