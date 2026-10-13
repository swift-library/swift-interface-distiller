// swift-tools-version: 6.3
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu
import PackageDescription

let package = Package(
  name: "InterfaceEvidenceConsumer",
  platforms: [.macOS(.v12)],
  dependencies: [
    .package(url: "https://github.com/swift-library/swift-interface-distiller.git", exact: "0.1.2")
  ],
  targets: [
    .executableTarget(
      name: "Consumer",
      dependencies: [.product(name: "InterfaceDistiller", package: "swift-interface-distiller")])
  ]
)
