// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftMocks",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftMocks",
            targets: ["SwiftMocks"]
        ),
        .executable(
            name: "SwiftMocksClient",
            targets: ["SwiftMocksClient"]
        ),
    ],
    dependencies: [
        // SwiftSyntax powers the @Mock macro. Span stable releases from Swift 5.9 (509)
        // up to the current 6.x line so the package builds across toolchains.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"603.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "SwiftMocksMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "SwiftMocks", dependencies: ["SwiftMocksMacros"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "SwiftMocksClient", dependencies: ["SwiftMocks"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "SwiftMocksTests",
            dependencies: [
                "SwiftMocks",
                "SwiftMocksMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

// DocC is only needed when building documentation, so it's gated behind an environment
// variable to keep it out of consumers' dependency graphs.
if Context.environment["SWIFTMOCKS_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    )
}
