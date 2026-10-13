// swift-tools-version: 6.3
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu
import PackageDescription

let package = Package(
  name: "EvidenceExample",
  products: [.library(name: "EvidenceExample", targets: ["EvidenceExample"])],
  targets: [.target(name: "EvidenceExample")])
