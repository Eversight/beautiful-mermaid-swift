// Ported from original/src/multiline-utils.ts
import Foundation
import LayoutKernel

public enum MultilineText {

    private struct StyledSegment {
        var text: String
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
    }

    public static func normalizeBrTags(_ label: String) -> String {
        let unquoted: String
        if label.hasPrefix("\"") && label.hasSuffix("\"") && label.count >= 2 {
            unquoted = String(label.dropFirst().dropLast())
        } else {
            unquoted = label
        }

        var result = unquoted
        // Most labels contain no tags or markdown at all; the marker checks
        // skip five ICU matcher runs per label on the parse/measure hot path.
        // Both tag patterns can only match when a "<" is present in the input
        // (they run before the markdown rewrites that introduce tags).
        if result.contains("<") {
            result = regexReplace(result, regex: _brRegex, template: "\n")
        }
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        if result.contains("<") {
            result = regexReplace(result, regex: _subSupRegex, template: "")
        }

        // Markdown formatting -> HTML tags (order matters)
        if result.contains("*") {
            result = regexReplace(result, regex: _boldRegex, template: "<b>$1</b>")
            result = regexReplace(result, regex: _italicRegex, template: "<i>$1</i>")
        }
        if result.contains("~") {
            result = regexReplace(result, regex: _strikeRegex, template: "<s>$1</s>")
        }

        return result
    }

    public static func stripFormattingTags(_ text: String) -> String {
        regexReplace(text, regex: _formattingTagRegex, template: "")
    }

    public static func escapeXml(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    public static func renderMultilineText(
        _ text: String,
        cx: Double,
        cy: Double,
        fontSize: Double,
        attrs: String,
        baselineShift: Double = 0.35
    ) -> String {
        let lines = text.components(separatedBy: "\n")
        if lines.count == 1 {
            let dy = fontSize * baselineShift
            return "<text x=\"\(cx)\" y=\"\(cy)\" \(attrs) dy=\"\(dy)\">\(renderLineContent(text))</text>"
        }

        let lineHeight = fontSize * TextMetrics.LINE_HEIGHT_RATIO
        let firstDy = -Double(lines.count - 1) / 2.0 * lineHeight + fontSize * baselineShift

        var tspans: [String] = []
        for (idx, line) in lines.enumerated() {
            let dy = idx == 0 ? firstDy : lineHeight
            tspans.append("<tspan x=\"\(cx)\" dy=\"\(dy)\">\(renderLineContent(line))</tspan>")
        }

        return "<text x=\"\(cx)\" y=\"\(cy)\" \(attrs)>\(tspans.joined())</text>"
    }

    public static func renderMultilineTextWithBackground(
        _ text: String,
        cx: Double,
        cy: Double,
        textWidth: Double,
        textHeight: Double,
        fontSize: Double,
        padding: Double,
        textAttrs: String,
        bgAttrs: String
    ) -> String {
        let bgWidth = textWidth + padding * 2
        let bgHeight = textHeight + padding * 2

        let rect = "<rect x=\"\(cx - bgWidth / 2)\" y=\"\(cy - bgHeight / 2)\" width=\"\(bgWidth)\" height=\"\(bgHeight)\" \(bgAttrs) />"
        let textEl = renderMultilineText(text, cx: cx, cy: cy, fontSize: fontSize, attrs: textAttrs)
        return "\(rect)\n\(textEl)"
    }

    private static func renderLineContent(_ line: String) -> String {
        if !hasFormatTags(line) {
            return escapeXml(line)
        }

        let segments = parseInlineFormatting(line)
        if segments.isEmpty {
            return ""
        }

        let allPlain = segments.allSatisfy { !$0.bold && !$0.italic && !$0.underline && !$0.strikethrough }
        if allPlain {
            return segments.map { escapeXml($0.text) }.joined()
        }

        return segments.map { seg in
            let escaped = escapeXml(seg.text)
            if !seg.bold && !seg.italic && !seg.underline && !seg.strikethrough {
                return escaped
            }

            var attrs: [String] = []
            if seg.bold {
                attrs.append("font-weight=\"bold\"")
            }
            if seg.italic {
                attrs.append("font-style=\"italic\"")
            }
            var deco: [String] = []
            if seg.underline {
                deco.append("underline")
            }
            if seg.strikethrough {
                deco.append("line-through")
            }
            if !deco.isEmpty {
                attrs.append("text-decoration=\"\(deco.joined(separator: " "))\"")
            }

            return "<tspan \(attrs.joined(separator: " "))>\(escaped)</tspan>"
        }.joined()
    }

    private static func hasFormatTags(_ line: String) -> Bool {
        // Cheap gate first: no "<" means no tags; skips the ICU matcher for
        // the overwhelming majority of labels.
        guard line.contains("<") else { return false }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return _formattingTagRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    /// Precompiled once — this used to compile per call on the SVG label path.
    private static let _inlineFormatRegex = _compile(#"<(\/)?(?:(b|strong)|(i|em)|(u)|(s|del))\s*>"#, [.caseInsensitive])

    private static func parseInlineFormatting(_ line: String) -> [StyledSegment] {
        let regex = _inlineFormatRegex

        var segments: [StyledSegment] = []
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var lastUtf16Index = 0

        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, options: [], range: fullRange)

        for match in matches {
            if match.range.location > lastUtf16Index {
                let start = String.Index(utf16Offset: lastUtf16Index, in: line)
                let end = String.Index(utf16Offset: match.range.location, in: line)
                if start <= end {
                let text = String(line[start..<end])
                segments.append(
                    StyledSegment(text: text, bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
                )
                }
            }

            let isClosing = rangeText(line, match.range(at: 1)) != nil
            if rangeText(line, match.range(at: 2)) != nil {
                bold = !isClosing
            } else if rangeText(line, match.range(at: 3)) != nil {
                italic = !isClosing
            } else if rangeText(line, match.range(at: 4)) != nil {
                underline = !isClosing
            } else if rangeText(line, match.range(at: 5)) != nil {
                strikethrough = !isClosing
            }

            lastUtf16Index = match.range.location + match.range.length
        }

        if lastUtf16Index < (line as NSString).length {
            let start = String.Index(utf16Offset: lastUtf16Index, in: line)
            let text = String(line[start...])
            segments.append(
                StyledSegment(text: text, bold: bold, italic: italic, underline: underline, strikethrough: strikethrough)
            )
        }

        return segments
    }

    private static func rangeText(_ source: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let r = Range(range, in: source)
        else {
            return nil
        }
        return String(source[r])
    }

    // Precompiled label-normalization patterns. Previously `regexReplace` compiled
    // a fresh NSRegularExpression on every call — 6 recompiles per label, on the
    // parse hot path. These `static let`s compile once, thread-safely; behavior is
    // identical (same patterns + options).
    private static let _brRegex = _compile(#"<br\s*/?>"#, [.caseInsensitive])
    private static let _subSupRegex = _compile(#"</?(?:sub|sup|small|mark)\s*>"#, [.caseInsensitive])
    private static let _boldRegex = _compile(#"\*\*(.+?)\*\*"#)
    private static let _italicRegex = _compile(#"\*([^\s*](?:[^*]*[^\s*])?)\*"#)
    private static let _strikeRegex = _compile(#"~~(.+?)~~"#)
    private static let _formattingTagRegex = _compile(#"</?(?:b|strong|i|em|u|s|del)\s*>"#, [.caseInsensitive])

    private static func _compile(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            assertionFailure("Invalid regex pattern: \(pattern)")
            return NSRegularExpression()
        }
        return regex
    }

    private static func regexReplace(
        _ source: String,
        regex: NSRegularExpression,
        template: String
    ) -> String {
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.stringByReplacingMatches(in: source, options: [], range: range, withTemplate: template)
    }
}
