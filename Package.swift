// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DaveSaveCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DaveSaveCore", targets: ["DaveSaveCore"]),
        .executable(name: "dtdcli", targets: ["dtdcli"])
    ],
    targets: [
        .target(
            name: "DaveSaveCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                // macOS-only v1: link the Apple SDK's system SQLite so the
                // later `import SQLite3` in ReferenceDB resolves with no edit here.
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "dtdcli",
            dependencies: ["DaveSaveCore"]
        ),
        .testTarget(
            name: "DaveSaveCoreTests",
            dependencies: ["DaveSaveCore"]
        )
    ]
)
