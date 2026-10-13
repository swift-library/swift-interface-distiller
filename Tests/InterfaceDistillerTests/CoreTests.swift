import Foundation
import Testing

@testable import InterfaceDistiller

@Test func digestVectors() {
  #expect(
    Digest.sha256(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  #expect(
    Digest.sha256(Data("abc".utf8))
      == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@Test func processDrainsBothStreams() async throws {
  let result = try await ProcessRunner(timeout: 10).checked(
    "/bin/sh",
    [
      "-c",
      "i=0; while [ $i -lt 5000 ]; do echo abcdefghijklmnopqrstuvwxyz; echo ABCDEFGHIJKLMNOPQRSTUVWXYZ >&2; i=$((i+1)); done",
    ], directory: URL(fileURLWithPath: "."))
  #expect(result.stdout.count == 135000)
  #expect(result.stderr.count == 135000)
}

@Test func processTimeoutKillsPipeHoldingChildren() async throws {
  do {
    _ = try await ProcessRunner(timeout: 0.1).run(
      "/bin/sh", ["-c", "sleep 30 & wait"], directory: URL(fileURLWithPath: "."))
    Issue.record("Expected timeout")
  } catch let error as DistillerError { #expect(error.code == .timeout) }
}

@Test func processCancellation() async throws {
  let task = Task {
    try await ProcessRunner().run(
      "/bin/sh", ["-c", "sleep 30"], directory: URL(fileURLWithPath: "."))
  }
  try await Task.sleep(for: .milliseconds(50))
  task.cancel()
  do {
    _ = try await task.value
    Issue.record("Expected cancellation")
  } catch let error as DistillerError { #expect(error.code == .cancelled) }
}
