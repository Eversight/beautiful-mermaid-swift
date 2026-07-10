import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

func _hex(_ color: BMColor) -> String? {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    #elseif canImport(AppKit)
    guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    return nil
    #endif

    let ri = Int(max(0, min(255, (r * 255).rounded())))
    let gi = Int(max(0, min(255, (g * 255).rounded())))
    let bi = Int(max(0, min(255, (b * 255).rounded())))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

private func _svgRegex(_ pattern: String) -> NSRegularExpression {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        assertionFailure("Invalid SVG regex pattern: \(pattern)")
        return NSRegularExpression()
    }
    return regex
}

// Precompiled once (thread-safe lazy init). Previously these 15 patterns were
// recompiled on every render — a fixed per-render cost paid even by tiny diagrams.
private let _svgTokenNames = [
    "_line", "_arrow", "_node-fill", "_node-stroke", "_group-fill", "_group-hdr",
    "_inner-stroke", "_text", "_text-sec", "_text-muted", "_state-end-outer", "_state-end-inner",
]
private let _svgTokenRegexCache: [String: NSRegularExpression] = {
    var d: [String: NSRegularExpression] = [:]
    d.reserveCapacity(_svgTokenNames.count)
    for t in _svgTokenNames {
        d[t] = _svgRegex(#"var\(\s*--\#(t)\s*(?:,\s*[^)]*)?\)"#)
    }
    return d
}()
private let _cssVarDefRegex = _svgRegex("--([a-zA-Z0-9_-]+)\\s*:\\s*([^;\\\"]+)")
private let _cssVarRefRegex = _svgRegex(#"var\(\s*--([a-zA-Z0-9_-]+)\s*(?:,\s*([^)]+))?\)"#)
private let _colorMixRegex = _svgRegex(#"color-mix\([^)]+\)"#)
private let _unresolvedVarRegex = _svgRegex(#"var\([^)]+\)"#)

/// Resolves every CSS custom property, known theme token, and rasterizer-
/// unsupported construct in an SVG to concrete values, in one forward pass.
///
/// Replaces the former `_resolveSvgCssVariables` + `_flattenKnownSvgTokens`
/// pair, which made ~28 full-string regex passes and rebuilt the whole string
/// per replacement (quadratic on match count). Per-occurrence precedence is
/// unchanged: style-block definition → non-empty `var()` fallback → known
/// theme token → left in place; then `color-mix(…)` and any still-unresolved
/// `var(…)` become `#666666` (AppKit/UIKit SVG rasterizers don't support
/// them). Replacement text is resolved recursively (bounded), matching the
/// old passes' iterate-until-stable behavior.
func _finalizeSvgColors(_ svg: String, theme: DiagramTheme) -> String {
    let bg = _hex(theme.background) ?? "#FFFFFF"
    let fg = _hex(theme.foreground) ?? "#27272A"
    let line = _hex(theme.effectiveLine()) ?? fg
    let muted = _hex(theme.effectiveMuted()) ?? line
    let surface = _hex(theme.effectiveSurface()) ?? bg
    let border = _hex(theme.effectiveBorder()) ?? line

    let tokens: [String: String] = [
        "_line": line,
        "_arrow": line,
        "_node-fill": surface,
        "_node-stroke": border,
        "_group-fill": surface,
        "_group-hdr": surface,
        "_inner-stroke": border,
        "_text": fg,
        "_text-sec": muted,
        "_text-muted": muted,
        "_state-end-outer": fg,
        "_state-end-inner": bg,
    ]

    // Collect `--name: value` definitions from the style block.
    var vars: [String: String] = [:]
    let ns = svg as NSString
    for m in _cssVarDefRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
    where m.numberOfRanges >= 3 {
        let name = ns.substring(with: m.range(at: 1))
        vars[name] = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // One forward pass substituting `var()` references; replacement text is
    // resolved recursively (`depth`-bounded — the old code iterated the whole
    // document to a fixed point with the same bound).
    func substituted(_ input: String, vars: [String: String], depth: Int) -> String {
        let source = input as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let varMatches = _cssVarRefRegex.matches(in: input, range: fullRange)
        if varMatches.isEmpty { return input }

        var out = String()
        out.reserveCapacity(input.utf16.count + 64)
        var cursor = 0
        for m in varMatches {
            out += source.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            cursor = m.range.location + m.range.length

            let key = source.substring(with: m.range(at: 1))
            let fallback: String? = (m.numberOfRanges >= 3 && m.range(at: 2).location != NSNotFound)
                ? source.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                : nil

            if let replacement = vars[key] ?? fallback, !replacement.isEmpty {
                out += depth > 0 ? substituted(replacement, vars: vars, depth: depth - 1) : replacement
            } else {
                out += "#666666"  // unresolved var() — rasterizers can't use it
            }
        }
        out += source.substring(from: cursor)
        return out
    }

    // Forward pass replacing `color-mix(…)` (unsupported by AppKit/UIKit SVG
    // rasterizers) with a solid color. Runs on the post-substitution text,
    // matching the old pipeline's pass order.
    func withoutColorMix(_ input: String) -> String {
        let source = input as NSString
        let matches = _colorMixRegex.matches(in: input, range: NSRange(location: 0, length: source.length))
        if matches.isEmpty { return input }
        var out = String()
        out.reserveCapacity(input.utf16.count)
        var cursor = 0
        for m in matches {
            out += source.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            out += "#666666"
            cursor = m.range.location + m.range.length
        }
        out += source.substring(from: cursor)
        return out
    }

    // No style-block definitions: the historical behavior applies only the
    // known-token replacements and leaves everything else (including
    // color-mix) untouched.
    if vars.isEmpty {
        let fullRange = NSRange(location: 0, length: ns.length)
        let varMatches = _cssVarRefRegex.matches(in: svg, range: fullRange)
        if varMatches.isEmpty { return svg }
        var out = String()
        out.reserveCapacity(svg.utf16.count)
        var cursor = 0
        for m in varMatches {
            let key = ns.substring(with: m.range(at: 1))
            guard let token = tokens[key] else { continue }
            out += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            out += token
            cursor = m.range.location + m.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    // Resolve definitions against each other first, as before.
    for _ in 0..<8 {
        var changed = false
        for (k, v) in vars where v.contains("var(") {
            let rv = substituted(v, vars: vars, depth: 4)
            if rv != v {
                vars[k] = rv
                changed = true
            }
        }
        if !changed { break }
    }

    return withoutColorMix(substituted(svg, vars: vars, depth: 15))
}
