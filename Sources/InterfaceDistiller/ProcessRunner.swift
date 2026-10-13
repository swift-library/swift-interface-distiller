// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import ProcessSupport

public struct ProcessOutput: Sendable {
  public var stdout: Data
  public var stderr: Data
  public var status: Int32
}

/// Executes in a dedicated process group, draining both streams while the child runs.
public struct ProcessRunner: Sendable {
  public var timeout: Double
  public var outputLimit: Int
  public init(timeout: Double = 600, outputLimit: Int = 128 * 1024 * 1024) {
    self.timeout = timeout
    self.outputLimit = outputLimit
  }

  public func run(
    _ executable: String, _ arguments: [String], directory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) async throws -> ProcessOutput {
    guard timeout > 0, timeout.isFinite, outputLimit > 0 else {
      throw DistillerError(.usage, "Timeout and output limit must be positive")
    }
    guard
      !([executable] + arguments + environment.map { $0.key + $0.value }).contains(where: {
        $0.contains("\0")
      })
    else {
      throw DistillerError(.usage, "Subprocess arguments cannot contain a null byte")
    }
    let executable =
      executable.contains("/")
      ? executable
      : (environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: false).map {
        URL(fileURLWithPath: String($0), relativeTo: directory).appendingPathComponent(executable)
          .path
      }.first(where: FileManager.default.isExecutableFile(atPath:)) ?? executable
    let state = try ProcessState()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
          do {
            let result = try state.run(
              executable, arguments, directory: directory,
              environment: environment, timeout: timeout, outputLimit: outputLimit)
            continuation.resume(returning: result)
          } catch { continuation.resume(throwing: error) }
        }
      }
    } onCancel: {
      state.cancel()
    }
  }

  public func checked(
    _ executable: String, _ arguments: [String], directory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) async throws -> ProcessOutput {
    let result = try await run(
      executable, arguments, directory: directory, environment: environment)
    guard result.status == 0 else {
      throw DistillerError(
        .processFailed, "Subprocess returned a failure",
        context: [
          "executable": executable, "status": String(result.status),
          "stderr": String(decoding: result.stderr.suffix(16384), as: UTF8.self),
        ])
    }
    return result
  }
}

// The C handle contains only an atomic cancellation flag; one worker owns execution.
private final class ProcessState: @unchecked Sendable {
  let handle: OpaquePointer
  init() throws {
    guard let handle = id_process_create() else {
      throw DistillerError(.io, "Cannot allocate subprocess state")
    }
    self.handle = handle
  }
  deinit { id_process_destroy(handle) }
  func cancel() { id_process_cancel(handle) }
  func run(
    _ executable: String, _ arguments: [String], directory: URL,
    environment: [String: String], timeout: Double, outputLimit: Int
  ) throws -> ProcessOutput {
    let argv = ([executable] + arguments).map { strdup($0) } + [nil]
    let env = environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer {
      for pointer in argv { free(pointer) }
      for pointer in env { free(pointer) }
    }
    var result = id_process_run(handle, executable, argv, env, directory.path, timeout, outputLimit)
    defer { id_process_result_destroy(&result) }
    switch result.failure {
    case 1: throw DistillerError(.timeout, "Subprocess exceeded timeout")
    case 2: throw DistillerError(.cancelled, "Subprocess cancelled")
    case 3:
      throw DistillerError(
        .io, "Subprocess system failure", context: ["errno": String(result.system_error)])
    case 4: throw DistillerError(.processFailed, "Subprocess output exceeded the configured limit")
    default: break
    }
    return ProcessOutput(
      stdout: result.out_bytes.map { Data(bytes: $0, count: result.out_count) } ?? Data(),
      stderr: result.err_bytes.map { Data(bytes: $0, count: result.err_count) } ?? Data(),
      status: result.exit_status)
  }
}
