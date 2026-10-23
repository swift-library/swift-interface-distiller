// swift-tools-version: 6.3
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu
import PackageDescription

let package = Package(
  name: "SnapshotExample",
  products: [.library(name: "SnapshotExample", targets: ["SnapshotExample"])],
  targets: [.target(name: "SnapshotExample")])
