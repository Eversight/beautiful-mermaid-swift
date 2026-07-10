import XCTest
@testable import BeautifulMermaid

/// Byte-for-byte golden guard for the public render surface.
///
/// This is the correctness oracle for the performance-optimization effort: every
/// optimization must leave `renderSVG`, plain `renderASCII`, and colored (role)
/// `renderASCII` output identical to what the pre-optimization code produced.
///
/// Recording: run once with `RECORD_GOLDEN=1` to (re)generate the snapshots from
/// the current (known-correct) code, then commit them. Thereafter the test asserts
/// equality. Never record and assert in the same intent — recording overwrites the
/// oracle.
///
///     RECORD_GOLDEN=1 swift test --filter GoldenOutputTests   # regenerate
///     swift test --filter GoldenOutputTests                   # verify
final class GoldenOutputTests: XCTestCase {

    /// Fixtures chosen to exercise the paths the optimizations touch: flowchart
    /// parsing + ASCII drawing (arrows, corners, labels, converging edges, LR),
    /// plus one of every other diagram type for broad SVG/ASCII coverage.
    static let fixtures: [(name: String, source: String)] = [
        ("flowchart_basic", """
        graph TD
            A[Start] --> B{Decision}
            B -->|Yes| C[Do Something]
            B -->|No| D[Do Something Else]
            C --> E[End]
            D --> E
        """),
        ("flowchart_shapes_labels", """
        graph TD
            A[Client Request] --> B{Auth Valid?}
            B -->|Yes| C[Load Balancer]
            B -->|No| Z[401 Unauthorized]
            C --> D[Service A]
            C --> E[Service B]
            D --> G[(Database)]
            E --> G
            G --> I[Response Builder]
            I --> J[Client Response]
            Z --> J
        """),
        ("flowchart_lr", """
        graph LR
            A[Ingest] --> B[Transform]
            B --> C[Validate]
            C -->|ok| D[Store]
            C -->|bad| E[Reject]
        """),
        ("state", """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Running: start
            Running --> Idle: stop
            Running --> [*]
        """),
        ("sequence", """
        sequenceDiagram
            participant U as User
            participant A as API
            participant D as Database
            U->>A: POST /login
            A->>D: SELECT user
            D-->>A: user row
            A-->>U: 200 OK + token
        """),
        ("class", """
        classDiagram
            class Animal {
                +String name
                +int age
                +makeSound() void
            }
            class Dog {
                +String breed
                +bark() void
            }
            Animal <|-- Dog
        """),
        ("er", """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE_ITEM : contains
            CUSTOMER {
                string name
                string email
            }
            ORDER {
                int id
                date created
            }
        """),
        ("xychart", """
        xychart-beta
            title "Revenue"
            x-axis [jan, feb, mar, apr, may, jun]
            y-axis "Revenue ($)" 0 --> 10000
            bar [5000, 6000, 7500, 8200, 9100, 9800]
            line [5000, 6000, 7500, 8200, 9100, 9800]
        """),
        // Fan-in / fan-out heavy — exercises edge bundling + junction merging.
        ("flowchart_fan", """
        graph TD
            A[Source] --> H[Hub]
            B[B] --> H
            C[C] --> H
            D[D] --> H
            H --> W[W]
            H --> X[X]
            H --> Y[Y]
            H --> Z[Z]
        """),
        // Bidirectional + branching — exercises start arrowheads and corners.
        ("flowchart_bidir", """
        graph LR
            A[Alpha] <--> B[Beta]
            B --> C{Choice}
            C -->|left| D[Delta]
            C -->|right| E[Echo]
            D <--> E
        """),
    ]

    // Fixed theme for colored ASCII so truecolor role escapes are deterministic.
    static let asciiColorTheme = AsciiIndex.AsciiTheme(values: [
        "fg": "#c0caf5", "border": "#565f89", "line": "#565f89", "arrow": "#565f89",
    ])

    private var goldenDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Golden", isDirectory: true)
    }

    private func renders(for source: String) throws -> [(suffix: String, content: String)] {
        let svg = try MermaidRenderer.renderSVG(source: source)
        let asciiPlain = try AsciiIndex.renderMermaidASCII(
            source, options: .init(colorMode: .explicit(.none))
        )
        let asciiColor = try AsciiIndex.renderMermaidASCII(
            source, options: .init(colorMode: .explicit(.truecolor), theme: Self.asciiColorTheme)
        )
        return [("svg", svg), ("plain.ascii", asciiPlain), ("color.ascii", asciiColor)]
    }

    func test_goldenOutputsAreStable() throws {
        let recording = ProcessInfo.processInfo.environment["RECORD_GOLDEN"] == "1"
        if recording {
            try FileManager.default.createDirectory(at: goldenDir, withIntermediateDirectories: true)
        }

        for fixture in Self.fixtures {
            let outputs = try renders(for: fixture.source)
            for (suffix, content) in outputs {
                let file = goldenDir.appendingPathComponent("\(fixture.name).\(suffix)")
                if recording {
                    try content.write(to: file, atomically: true, encoding: .utf8)
                    continue
                }
                guard let expected = try? String(contentsOf: file, encoding: .utf8) else {
                    XCTFail("Missing golden \(file.lastPathComponent). Run with RECORD_GOLDEN=1 first.")
                    continue
                }
                if expected != content {
                    XCTFail("Golden mismatch for \(fixture.name).\(suffix): output changed (\(expected.count) → \(content.count) chars). A supposedly behavior-preserving change altered rendered output.")
                }
            }
        }
    }
}
