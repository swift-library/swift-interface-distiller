// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "swift-interface-distiller",
  platforms: [.macOS(.v12)],
  products: [
    .library(name: "InterfaceDistiller", targets: ["InterfaceDistiller"]),
    .executable(name: "interface-distiller", targets: ["InterfaceDistillerCLI"]),
  ],
  targets: [
    .target(name: "ProcessSupport"),
    .target(name: "InterfaceDistiller", dependencies: ["ProcessSupport"]),
    .executableTarget(name: "InterfaceDistillerCLI", dependencies: ["InterfaceDistiller"]),
    .testTarget(
      name: "InterfaceDistillerTests", dependencies: ["InterfaceDistiller"],
      resources: [.copy("Fixtures")]),
  ]
)
