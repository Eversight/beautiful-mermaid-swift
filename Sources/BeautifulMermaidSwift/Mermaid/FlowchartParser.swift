// Ported from original/src/parser.ts
import Foundation
import LayoutKernel

private typealias ParsedDirection = CoreTypes.Direction
private typealias ParsedNodeShape = CoreTypes.NodeShape
private typealias ParsedEdgeStyle = CoreTypes.EdgeStyle
private typealias ParsedNode = CoreTypes.MermaidNode
private typealias ParsedEdge = CoreTypes.MermaidEdge
private typealias ParsedSubgraph = CoreTypes.MermaidSubgraph
private typealias ParsedGraph = CoreTypes.MermaidGraph

private enum _ParserEntryError: Error {
    case emptyDiagram
    case invalidHeader(String)
}

private struct _WorkingGraph {
    var direction: ParsedDirection
    var nodesById: [String: ParsedNode] = [:]
    var nodeOrder: [String] = []
    var edges: [ParsedEdge] = []
    var subgraphs: [ParsedSubgraph] = []
    var subgraphIds: Set<String> = []
    var classDefs: [String: [String: String]] = [:]
    var classAssignments: [String: String] = [:]
    var nodeStyles: [String: [String: String]] = [:]
    /// Maps edge indices (or -1 for 'default') to inline styles from `linkStyle` directives
    var linkStyles: [Int: [String: String]] = [:]

    mutating func upsertNode(_ node: ParsedNode) {
        if nodesById[node.id] == nil {
            nodeOrder.append(node.id)
        }
        nodesById[node.id] = node
    }

    mutating func mergeNodeStyle(_ id: String, _ props: [String: String]) {
        var merged = nodeStyles[id] ?? [:]
        for (k, v) in props {
            merged[k] = v
        }
        nodeStyles[id] = merged
    }

    func toParsedGraph() -> ParsedGraph {
        let nodesInOrder: [(id: String, node: ParsedNode)] = nodeOrder.compactMap { id in
            guard let node = nodesById[id] else { return nil }
            return (id: id, node: node)
        }
        return ParsedGraph(
            direction: direction,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs,
            classDefs: classDefs,
            classAssignments: classAssignments,
            nodeStyles: nodeStyles,
            linkStyles: linkStyles
        )
    }
}

private struct _ConsumedNode {
    var id: String
    var remaining: String
}

private struct _ConsumedNodeGroup {
    var ids: [String]
    var remaining: String
}

private func _regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        assertionFailure("Invalid regex pattern: \(pattern)")
        return NSRegularExpression()
    }
    return regex
}

// Precompiled line-dispatch patterns. These were previously recompiled on every
// line via `_regexTest`/`_regexGroups(pattern:)` — the dominant parse cost on
// large diagrams. Module-level `let`s are lazily and thread-safely initialized
// once, so this is behavior-identical (same pattern + options) and lock-free.
private let _stateHeaderRegex = _regex(#"^stateDiagram(-v2)?\s*$"#, [.caseInsensitive])
private let _graphHeaderRegex = _regex(#"^(?:graph|flowchart)\s+(TD|TB|LR|BT|RL)\s*$"#, [.caseInsensitive])
private let _subgraphRegex = _regex(#"^subgraph\s+(.+)$"#)
private let _subgraphBracketRegex = _regex(#"^([\w-]+)\s*\[(.+)\]$"#)
private let _classDefRegex = _regex(#"^classDef\s+(\w+)\s+(.+)$"#)
private let _classAssignRegex = _regex(#"^class\s+([\w,-]+)\s+(\w+)$"#)
private let _styleLineRegex = _regex(#"^style\s+([\w,-]+)\s+(.+)$"#)
private let _linkStyleRegex = _regex(#"^linkStyle\s+(default|[\d,\s]+)\s+(.+)$"#)
private let _directionLineRegex = _regex(#"^direction\s+(TD|TB|LR|BT|RL)\s*$"#, [.caseInsensitive])
private let _stateCompositeRegex = _regex(#"^state\s+(?:\"([^\"]+)\"\s+as\s+)?([\w\p{L}]+)\s*\{$"#)
private let _stateAliasRegex = _regex(#"^state\s+\"([^\"]+)\"\s+as\s+([\w\p{L}]+)\s*$"#)
private let _stateTransitionRegex = _regex(#"^(\[\*\]|[\w\p{L}-]+)\s*(-->)\s*(\[\*\]|[\w\p{L}-]+)(?:\s*:\s*(.+))?$"#)
private let _stateDescRegex = _regex(#"^([\w\p{L}-]+)\s*:\s*(.+)$"#)

private let _arrowRegex = _regex(#"^(<)?(-->|-.->|==>|---|-\.-|===)(?:\|([^|]*)\|)?"#)

/// Text-embedded label regex — matches "-- label -->", "-. label .->", "== label ==>" syntax.
/// Group 1: optional `<` for bidirectional
/// Group 2: opening prefix (`--`, `-.`, `==`)
/// Group 3: label text
/// Group 4: closing arrow/line (`-->`, `---`, `.->`, `-.-`, `==>`, `===`)
private let _textEmbeddedArrowRegex = _regex(#"^(<)?(--|-\.|==)\s+(.+?)\s+(-->|---|\.\->|-\.\-|==>|===)"#)
private let _bareNodeRegex = _regex(#"^([\w-]+)"#)
private let _classShorthandRegex = _regex(#"^:::([\w][\w-]*)"#)

private let _nodePatterns: [(regex: NSRegularExpression, shape: ParsedNodeShape)] = [
    (_regex(#"^([\w-]+)\(\(\((.+?)\)\)\)"#), .doublecircle),
    (_regex(#"^([\w-]+)\(\[(.+?)\]\)"#), .stadium),
    (_regex(#"^([\w-]+)\(\((.+?)\)\)"#), .circle),
    (_regex(#"^([\w-]+)\[\[(.+?)\]\]"#), .subroutine),
    (_regex(#"^([\w-]+)\[\((.+?)\)\]"#), .cylinder),
    (_regex(#"^([\w-]+)\[\/(.+?)\\\]"#), .trapezoid),
    (_regex(#"^([\w-]+)\[\\(.+?)\/\]"#), .trapezoidAlt),
    (_regex(#"^([\w-]+)>(.+?)\]"#), .asymmetric),
    (_regex(#"^([\w-]+)\{\{(.+?)\}\}"#), .hexagon),
    (_regex(#"^([\w-]+)\[(.+?)\]"#), .rectangle),
    (_regex(#"^([\w-]+)\((.+?)\)"#), .rounded),
    (_regex(#"^([\w-]+)\{(.+?)\}"#), .diamond),
]

public func parseMermaid(_ text: String) throws -> MermaidGraph {
    try _parseMermaidEntry(text)
}

private func _parseMermaidEntry(_ text: String) throws -> MermaidGraph {
    let lines = text
        .components(separatedBy: CharacterSet(charactersIn: "\n;"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

    guard !lines.isEmpty else {
        throw _ParserEntryError.emptyDiagram
    }

    let header = lines[0]
    let parsed: ParsedGraph
    let diagramType: DiagramType

    if _regexTest(_stateHeaderRegex, header) {
        parsed = try _parseStateDiagram(lines)
        diagramType = .stateDiagram
    } else {
        parsed = try _parseFlowchart(lines)
        diagramType = .flowchart
    }

    return MermaidGraph(type: diagramType, payload: parsed)
}

private func _parseFlowchart(_ lines: [String]) throws -> ParsedGraph {
    guard let header = lines.first else {
        throw _ParserEntryError.invalidHeader("")
    }

    guard let match = _regexMatch(_graphHeaderRegex, header),
          let dirToken = match[safe: 1],
          let direction = _parseDirection(dirToken)
    else {
        throw _ParserEntryError.invalidHeader(header)
    }

    var graph = _WorkingGraph(direction: direction)
    var subgraphStack: [ParsedSubgraph] = []

    if lines.count <= 1 {
        return graph.toParsedGraph()
    }

    // Pre-scan: collect all subgraph IDs so forward-referenced subgraphs aren't
    // mistaken for bare nodes during edge parsing.
    for line in lines.dropFirst() {
        if let subgraphMatch = _regexMatch(_subgraphRegex, line),
           let restRaw = subgraphMatch[safe: 1]
        {
            let rest = restRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let bracketMatch = _regexMatch(_subgraphBracketRegex, rest),
               let foundId = bracketMatch[safe: 1]
            {
                graph.subgraphIds.insert(foundId)
            } else {
                let id = rest
                    .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
                    .replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
                graph.subgraphIds.insert(id)
            }
        }
    }

    for line in lines.dropFirst() {
        if let classDefMatch = _regexMatch(_classDefRegex, line),
           let name = classDefMatch[safe: 1],
           let propsStr = classDefMatch[safe: 2]
        {
            graph.classDefs[name] = _parseStyleProps(propsStr)
            continue
        }

        if let classAssignMatch = _regexMatch(_classAssignRegex, line),
           let idsRaw = classAssignMatch[safe: 1],
           let className = classAssignMatch[safe: 2]
        {
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                graph.classAssignments[id] = className
            }
            continue
        }

        if let styleMatch = _regexMatch(_styleLineRegex, line),
           let idsRaw = styleMatch[safe: 1],
           let propsRaw = styleMatch[safe: 2]
        {
            let props = _parseStyleProps(propsRaw)
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                graph.mergeNodeStyle(id, props)
            }
            continue
        }

        // --- linkStyle: `linkStyle 0 stroke:#f00` or `linkStyle default stroke:#f00` ---
        if let lsMatch = _regexMatch(_linkStyleRegex, line),
           let target = lsMatch[safe: 1],
           let propsRaw = lsMatch[safe: 2]
        {
            let props = _parseStyleProps(propsRaw)
            if target.trimmingCharacters(in: .whitespacesAndNewlines) == "default" {
                var merged = graph.linkStyles[-1] ?? [:]
                for (k, v) in props { merged[k] = v }
                graph.linkStyles[-1] = merged
            } else {
                for part in target.split(separator: ",") {
                    if let idx = Int(part.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        var merged = graph.linkStyles[idx] ?? [:]
                        for (k, v) in props { merged[k] = v }
                        graph.linkStyles[idx] = merged
                    }
                }
            }
            continue
        }

        if let dirMatch = _regexMatch(_directionLineRegex, line),
           let dirToken = dirMatch[safe: 1],
           let dir = _parseDirection(dirToken),
           !subgraphStack.isEmpty
        {
            subgraphStack[subgraphStack.count - 1].direction = dir
            continue
        }

        if let subgraphMatch = _regexMatch(_subgraphRegex, line),
           let restRaw = subgraphMatch[safe: 1]
        {
            let rest = restRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let id: String
            let label: String

            if let bracketMatch = _regexMatch(_subgraphBracketRegex, rest),
               let foundId = bracketMatch[safe: 1],
               let foundLabel = bracketMatch[safe: 2]
            {
                id = foundId
                label = MultilineText.normalizeBrTags(foundLabel)
            } else {
                label = MultilineText.normalizeBrTags(rest)
                id = rest
                    .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
                    .replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
            }

            graph.subgraphIds.insert(id)
            subgraphStack.append(ParsedSubgraph(id: id, label: label, nodeIds: [], children: [], direction: nil))
            continue
        }

        if line == "end" {
            let completed = subgraphStack.popLast()
            if let completed {
                if !subgraphStack.isEmpty {
                    subgraphStack[subgraphStack.count - 1].children.append(completed)
                } else {
                    graph.subgraphs.append(completed)
                }
            }
            continue
        }

        _parseEdgeLine(line, graph: &graph, subgraphStack: &subgraphStack)
    }

    return graph.toParsedGraph()
}

private func _parseStateDiagram(_ lines: [String]) throws -> ParsedGraph {
    var graph = _WorkingGraph(direction: .TD)

    var compositeStack: [ParsedSubgraph] = []
    var compositeStateIds = Set<String>()
    var startCount = 0
    var endCount = 0

    if lines.count <= 1 {
        return graph.toParsedGraph()
    }

    for line in lines.dropFirst() {
        if let dirMatch = _regexMatch(_directionLineRegex, line),
           let dirToken = dirMatch[safe: 1],
           let direction = _parseDirection(dirToken)
        {
            if !compositeStack.isEmpty {
                compositeStack[compositeStack.count - 1].direction = direction
            } else {
                graph.direction = direction
            }
            continue
        }

        // --- linkStyle in state diagrams ---
        if let lsMatch = _regexMatch(_linkStyleRegex, line),
           let target = lsMatch[safe: 1],
           let propsRaw = lsMatch[safe: 2]
        {
            let props = _parseStyleProps(propsRaw)
            if target.trimmingCharacters(in: .whitespacesAndNewlines) == "default" {
                var merged = graph.linkStyles[-1] ?? [:]
                for (k, v) in props { merged[k] = v }
                graph.linkStyles[-1] = merged
            } else {
                let indices = target.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                for idx in indices {
                    var merged = graph.linkStyles[idx] ?? [:]
                    for (k, v) in props { merged[k] = v }
                    graph.linkStyles[idx] = merged
                }
            }
            continue
        }

        if let compositeMatch = _regexMatch(_stateCompositeRegex, line),
           let id = compositeMatch[safe: 2]
        {
            let raw1 = compositeMatch[safe: 1]
            let label = (raw1?.isEmpty == false) ? raw1! : id
            compositeStack.append(ParsedSubgraph(id: id, label: label, nodeIds: [], children: [], direction: nil))
            compositeStateIds.insert(id)
            graph.nodesById.removeValue(forKey: id)
            graph.nodeOrder.removeAll { $0 == id }
            continue
        }

        if line == "}" {
            let completed = compositeStack.popLast()
            if let completed {
                if !compositeStack.isEmpty {
                    compositeStack[compositeStack.count - 1].children.append(completed)
                } else {
                    graph.subgraphs.append(completed)
                }
            }
            continue
        }

        if let aliasMatch = _regexMatch(_stateAliasRegex, line),
           let labelRaw = aliasMatch[safe: 1],
           let id = aliasMatch[safe: 2]
        {
            let label = MultilineText.normalizeBrTags(labelRaw)
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: label, shape: .rounded))
            continue
        }

        if let transitionMatch = _regexMatch(_stateTransitionRegex, line),
           let sourceRaw = transitionMatch[safe: 1],
           let targetRaw = transitionMatch[safe: 3]
        {
            var sourceId = sourceRaw
            var targetId = targetRaw
            let rawLabel = transitionMatch[safe: 4]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let edgeLabel = (rawLabel?.isEmpty == false) ? MultilineText.normalizeBrTags(rawLabel!) : nil

            if sourceId == "[*]" {
                startCount += 1
                sourceId = startCount > 1 ? "_start\(startCount)" : "_start"
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: sourceId, label: "", shape: .stateStart))
            } else if !compositeStateIds.contains(sourceId) {
                _ensureStateNode(&graph, &compositeStack, sourceId)
            }

            if targetId == "[*]" {
                endCount += 1
                targetId = endCount > 1 ? "_end\(endCount)" : "_end"
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: targetId, label: "", shape: .stateEnd))
            } else if !compositeStateIds.contains(targetId) {
                _ensureStateNode(&graph, &compositeStack, targetId)
            }

            graph.edges.append(
                ParsedEdge(
                    source: sourceId,
                    target: targetId,
                    label: edgeLabel,
                    style: .solid,
                    hasArrowStart: false,
                    hasArrowEnd: true
                )
            )
            continue
        }

        if let descMatch = _regexMatch(_stateDescRegex, line),
           let id = descMatch[safe: 1],
           let labelRaw = descMatch[safe: 2]
        {
            let label = MultilineText.normalizeBrTags(labelRaw.trimmingCharacters(in: .whitespacesAndNewlines))
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: label, shape: .rounded))
            continue
        }
    }

    return graph.toParsedGraph()
}

private func _registerStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    let isNew = graph.nodesById[node.id] == nil
    if isNew {
        graph.upsertNode(node)
    }
    if !compositeStack.isEmpty {
        let current = compositeStack[compositeStack.count - 1]
        if !current.nodeIds.contains(node.id) {
            current.nodeIds.append(node.id)
        }
    }
}

private func _ensureStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ id: String) {
    if graph.nodesById[id] == nil {
        _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: id, shape: .rounded))
    } else if !compositeStack.isEmpty {
        let current = compositeStack[compositeStack.count - 1]
        if !current.nodeIds.contains(id) {
            current.nodeIds.append(id)
        }
    }
}

private func _parseStyleProps(_ propsStr: String) -> [String: String] {
    // Strip trailing semicolons — Mermaid tolerates them (e.g. `stroke:#f00;`)
    let cleaned = propsStr.replacingOccurrences(of: #";[\s]*$"#, with: "", options: .regularExpression)
    var props: [String: String] = [:]
    for pair in cleaned.split(separator: ",", omittingEmptySubsequences: false) {
        let item = String(pair)
        guard let idx = item.firstIndex(of: ":") else { continue }
        let key = item[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = item[item.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty, !value.isEmpty {
            props[key] = value
        }
    }
    return props
}

private func _parseEdgeLine(_ line: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) {
    var remaining = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let firstGroup = _consumeNodeGroup(remaining, graph: &graph, subgraphStack: &subgraphStack), !firstGroup.ids.isEmpty else {
        return
    }

    remaining = firstGroup.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    var prevGroupIds = firstGroup.ids

    while !remaining.isEmpty {
        var hasArrowStart = false
        var edgeLabel: String?
        var style: ParsedEdgeStyle
        var hasArrowEnd: Bool

        if let arrowMatch = _regexMatch(_arrowRegex, remaining),
           let full = arrowMatch[safe: 0],
           let op = arrowMatch[safe: 2]
        {
            hasArrowStart = !(arrowMatch[safe: 1] ?? "").isEmpty
            let rawLabel = arrowMatch[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines)
            edgeLabel = (rawLabel?.isEmpty == false) ? MultilineText.normalizeBrTags(rawLabel!) : nil
            remaining = String(remaining.dropFirst(full.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            style = _arrowStyleFromOp(op)
            hasArrowEnd = op.hasSuffix(">")
        } else if let teMatch = _regexMatch(_textEmbeddedArrowRegex, remaining),
                  let full = teMatch[safe: 0],
                  let openOp = teMatch[safe: 2],
                  let labelText = teMatch[safe: 3],
                  let closeOp = teMatch[safe: 4]
        {
            // Fallback: text-embedded label syntax (-- Yes -->, -. Maybe .->, == Sure ==>)
            hasArrowStart = !(teMatch[safe: 1] ?? "").isEmpty
            let trimmedLabel = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
            edgeLabel = trimmedLabel.isEmpty ? nil : MultilineText.normalizeBrTags(trimmedLabel)
            remaining = String(remaining.dropFirst(full.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            style = _textArrowStyleFromOps(openOp, closeOp)
            hasArrowEnd = closeOp.hasSuffix(">")
        } else {
            break
        }

        guard let nextGroup = _consumeNodeGroup(remaining, graph: &graph, subgraphStack: &subgraphStack), !nextGroup.ids.isEmpty else {
            break
        }

        remaining = nextGroup.remaining.trimmingCharacters(in: .whitespacesAndNewlines)

        for sourceId in prevGroupIds {
            for targetId in nextGroup.ids {
                graph.edges.append(
                    ParsedEdge(
                        source: sourceId,
                        target: targetId,
                        label: edgeLabel,
                        style: style,
                        hasArrowStart: hasArrowStart,
                        hasArrowEnd: hasArrowEnd
                    )
                )
            }
        }

        prevGroupIds = nextGroup.ids
    }
}

private func _consumeNodeGroup(_ text: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) -> _ConsumedNodeGroup? {
    guard let first = _consumeNode(text, graph: &graph, subgraphStack: &subgraphStack) else {
        return nil
    }

    var ids: [String] = [first.id]
    var remaining = first.remaining.trimmingCharacters(in: .whitespacesAndNewlines)

    while remaining.hasPrefix("&") {
        remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let next = _consumeNode(remaining, graph: &graph, subgraphStack: &subgraphStack) else {
            break
        }
        ids.append(next.id)
        remaining = next.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return _ConsumedNodeGroup(ids: ids, remaining: remaining)
}

private func _consumeNode(_ text: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) -> _ConsumedNode? {
    var id: String?
    var remaining = text

    for pattern in _nodePatterns {
        guard let match = _regexMatch(pattern.regex, text),
              let full = match[safe: 0],
              let matchedId = match[safe: 1],
              let rawLabel = match[safe: 2]
        else {
            continue
        }

        let label = MultilineText.normalizeBrTags(rawLabel)
        _registerNode(&graph, &subgraphStack, ParsedNode(id: matchedId, label: label, shape: pattern.shape))
        id = matchedId
        remaining = String(text.dropFirst(full.count))
        break
    }

    if id == nil,
       let bare = _regexMatch(_bareNodeRegex, text),
       let full = bare[safe: 0],
       let bareId = bare[safe: 1]
    {
        id = bareId
        if graph.nodesById[bareId] == nil && !graph.subgraphIds.contains(bareId) {
            _registerNode(&graph, &subgraphStack, ParsedNode(id: bareId, label: bareId, shape: .rectangle))
        }
        remaining = String(text.dropFirst(full.count))
    }

    guard let nodeId = id else {
        return nil
    }

    if let classMatch = _regexMatch(_classShorthandRegex, remaining),
       let full = classMatch[safe: 0],
       let className = classMatch[safe: 1]
    {
        graph.classAssignments[nodeId] = className
        remaining = String(remaining.dropFirst(full.count))
    }

    return _ConsumedNode(id: nodeId, remaining: remaining)
}

private func _registerNode(_ graph: inout _WorkingGraph, _ subgraphStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    let isNew = graph.nodesById[node.id] == nil
    if isNew {
        graph.upsertNode(node)
    }
    _trackInSubgraph(&subgraphStack, node.id)
}

private func _trackInSubgraph(_ subgraphStack: inout [ParsedSubgraph], _ nodeId: String) {
    if !subgraphStack.isEmpty {
        let current = subgraphStack[subgraphStack.count - 1]
        if !current.nodeIds.contains(nodeId) {
            current.nodeIds.append(nodeId)
        }
    }
}

private func _textArrowStyleFromOps(_ openOp: String, _ closeOp: String) -> ParsedEdgeStyle {
    if openOp == "-." || closeOp == ".->" || closeOp == "-.-" { return .dotted }
    if openOp == "==" || closeOp == "==>" || closeOp == "===" { return .thick }
    return .solid
}

private func _arrowStyleFromOp(_ op: String) -> ParsedEdgeStyle {
    if op == "-.->" || op == "-.-" {
        return .dotted
    }
    if op == "==>" || op == "===" {
        return .thick
    }
    return .solid
}

private func _parseDirection(_ token: String) -> ParsedDirection? {
    ParsedDirection(rawValue: token.uppercased())
}

private func _regexTest(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> Bool {
    _regexGroups(pattern, input, caseInsensitive: caseInsensitive) != nil
}

private func _regexTest(_ regex: NSRegularExpression, _ input: String) -> Bool {
    regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)) != nil
}

private func _regexGroups(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
          let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input))
    else {
        return nil
    }

    var groups: [String] = []
    for i in 0..<match.numberOfRanges {
        let nsRange = match.range(at: i)
        if nsRange.location == NSNotFound {
            groups.append("")
            continue
        }
        if let range = Range(nsRange, in: input) {
            groups.append(String(input[range]))
        } else {
            groups.append("")
        }
    }
    return groups
}

private func _regexMatch(_ regex: NSRegularExpression, _ input: String) -> [String]? {
    guard let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)) else {
        return nil
    }

    var groups: [String] = []
    for i in 0..<match.numberOfRanges {
        let nsRange = match.range(at: i)
        if nsRange.location == NSNotFound {
            groups.append("")
            continue
        }
        if let range = Range(nsRange, in: input) {
            groups.append(String(input[range]))
        } else {
            groups.append("")
        }
    }
    return groups
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

