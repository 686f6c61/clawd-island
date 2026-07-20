#!/usr/bin/env swift

import Foundation

let projectDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resourcesDirectory = projectDirectory.appendingPathComponent("Resources", isDirectory: true)
let states = ["idle", "working", "waiting", "completed", "failed", "update"]

for state in states {
    let sourceURL = resourcesDirectory.appendingPathComponent("Clawd-\(state).svg")
    let destinationURL = resourcesDirectory.appendingPathComponent("Clawdia-\(state).svg")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    guard source.contains("</svg>") else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let output = source.replacingOccurrences(
        of: "</svg>",
        with: "\(ClawdiaArtwork.markup(for: state))</svg>"
    )
    try output.write(to: destinationURL, atomically: true, encoding: .utf8)
    print(destinationURL.path)
}

private enum ClawdiaArtwork {
    static func markup(for state: String) -> String {
        """
        <style>
          .clawdia-bow {
            transform-origin: 12.5px 5.5px;
            animation: clawdia-bow-sway 2.8s infinite ease-in-out;
          }
          .clawdia-heart {
            opacity: 0;
            transform-origin: 2.5px 2.5px;
            animation: clawdia-heart-rise 2.5s infinite ease-out;
          }
          .clawdia-heart.h2 { animation-delay: -0.85s; }
          .clawdia-heart.h3 { animation-delay: -1.7s; }
          @keyframes clawdia-bow-sway {
            0%, 100% { transform: rotate(-3deg); }
            50% { transform: rotate(4deg); }
          }
          @keyframes clawdia-heart-rise {
            0% { opacity: 0; transform: translateY(0) scale(0.72); }
            14% { opacity: 0.95; }
            76% { opacity: 0.8; }
            100% { opacity: 0; transform: translateY(-11px) scale(1.08); }
          }
          @keyframes clawdia-heart-pulse {
            0%, 100% { opacity: 0.35; transform: scale(0.72); }
            50% { opacity: 1; transform: scale(1.05); }
          }
          @keyframes clawdia-bow-work {
            0%, 100% { transform: translateY(0) rotate(-4deg); }
            50% { transform: translateY(-0.5px) rotate(5deg); }
          }
          @keyframes clawdia-bow-droop {
            0%, 100% { transform: translateY(1px) rotate(12deg); }
            50% { transform: translateY(1.5px) rotate(16deg); }
          }
          \(stateStyle(for: state))
        </style>
        <g class="clawdia-blush" fill="#F06B9D" opacity="0.78">
          <rect x="2.7" y="10.2" width="1" height="0.65"/>
          <rect x="11.3" y="10.2" width="1" height="0.65"/>
        </g>
        <g class="clawdia-bow">
          <rect x="10" y="4" width="2" height="2" fill="#FF6FAE"/>
          <rect x="13" y="4" width="2" height="2" fill="#FF6FAE"/>
          <rect x="11" y="3" width="1" height="1" fill="#FF91C1"/>
          <rect x="14" y="3" width="1" height="1" fill="#FF91C1"/>
          <rect x="12" y="5" width="1" height="1" fill="#D83B82"/>
        </g>
        \(stateDecoration(for: state))
        """
    }

    private static func stateStyle(for state: String) -> String {
        switch state {
        case "working":
            ".clawdia-bow { animation: clawdia-bow-work 0.55s infinite ease-in-out; } .clawdia-blush { display: none; }"
        case "waiting":
            ".clawdia-wait-heart { animation: clawdia-heart-pulse 1.15s infinite ease-in-out; opacity: 1; }"
        case "failed":
            ".clawdia-bow { animation: clawdia-bow-droop 2s infinite ease-in-out; }"
        case "update":
            ".clawdia-bow { animation: clawdia-bow-sway 1.4s 1 ease-in-out; } .clawdia-sign-heart { animation: clawdia-heart-pulse 1.4s 1 ease-in-out; opacity: 0.65; }"
        default:
            ""
        }
    }

    private static func stateDecoration(for state: String) -> String {
        switch state {
        case "working":
            hearts([
                (x: -1.5, y: 8.5, scale: 0.48, cssClass: "h1"),
                (x: 14.0, y: 10.0, scale: 0.40, cssClass: "h2"),
                (x: 7.0, y: 5.0, scale: 0.34, cssClass: "h3"),
            ])
        case "completed":
            hearts([
                (x: -1.0, y: 9.0, scale: 0.46, cssClass: "h1"),
                (x: 14.0, y: 8.0, scale: 0.46, cssClass: "h2"),
                (x: 7.0, y: 4.0, scale: 0.38, cssClass: "h3"),
            ])
        case "waiting":
            heart(x: 15.0, y: 6.0, scale: 0.38, cssClass: "clawdia-wait-heart")
        case "failed":
            """
            <g transform="translate(-1 2) scale(0.38)">
              <path d="M0 1h1V0h1v1h1V0h1v1h1v2H4v1H3v1H2V4H1V3H0z" fill="#F05A91"/>
              <path d="M2 1h1v1H2v1h1v1H2" fill="#7C244C"/>
            </g>
            """
        case "update":
            heart(x: 16.2, y: -6.3, scale: 0.34, cssClass: "clawdia-sign-heart")
        default:
            ""
        }
    }

    private static func hearts(
        _ values: [(x: Double, y: Double, scale: Double, cssClass: String)]
    ) -> String {
        values.map {
            heart(x: $0.x, y: $0.y, scale: $0.scale, cssClass: "clawdia-heart \($0.cssClass)")
        }
        .joined(separator: "\n")
    }

    private static func heart(
        x: Double,
        y: Double,
        scale: Double,
        cssClass: String
    ) -> String {
        """
        <g transform="translate(\(x) \(y)) scale(\(scale))">
          <path class="\(cssClass)" d="M0 1h1V0h1v1h1V0h1v1h1v2H4v1H3v1H2V4H1V3H0z" fill="#FF5E9D"/>
        </g>
        """
    }
}
