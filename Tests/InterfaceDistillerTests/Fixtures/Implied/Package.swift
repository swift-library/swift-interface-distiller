// swift-tools-version: 6.3
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu
import PackageDescription

let package = Package(
  name: "ImpliedFixture",
  products: [.library(name: "ImpliedExample", targets: ["ImpliedExample"])],
  targets: [.target(name: "ImpliedExample")])
