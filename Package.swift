// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AddressVerification",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "AddressVerification",
            targets: ["AddressVerification"]
        ),
        .library(
            name: "AddressVerificationReactNative",
            targets: ["AddressVerificationReactNative"]
        )
    ],
    dependencies: [
        // Add any external dependencies if needed
    ],
    targets: [
        .target(
            name: "AddressVerification",
            path: "Sources/AddressVerification",
            exclude: [],
            sources: ["."],
            publicHeadersPath: nil
        ),
        .target(
            name: "AddressVerificationReactNative",
            dependencies: ["AddressVerification"],
//            path: "Sources/ReactNative",
            sources: ["."],
            swiftSettings: [
                .define("REACT_NATIVE_BUILD")
            ]
        )
    ]
)
