// swift-tools-version: 6.2
//
// Text Actions for PepBox: DropClip (MIT, based on OpenClip by Ganesh M) with
// OpenSelection (Apache-2.0), hosted by PepBox instead of Droppy. See Legal/.
//
import PackageDescription

let package = Package(
    name: "TextActionsKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TextActionsKit", targets: ["DropClip"])
    ],
    targets: [
        // Ganesh M's OpenSelection, the selection engine (Apache-2.0).
        .target(
            name: "OpenSelection",
            exclude: ["LICENSE.txt", "NOTICE.txt"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "DropClipCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "DropClip",
            dependencies: ["OpenSelection", "DropClipCore"],
            resources: [.copy("Resources/Assets")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
