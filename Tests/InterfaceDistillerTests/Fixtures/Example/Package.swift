// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "EvidenceExample",
  products: [.library(name: "EvidenceExample", targets: ["EvidenceExample"])],
  targets: [.target(name: "EvidenceExample")])
