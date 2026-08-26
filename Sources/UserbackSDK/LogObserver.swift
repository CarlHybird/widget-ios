import Foundation

#if canImport(UIKit) && canImport(WebKit)

public final class LogObserver {
    public static let shared = LogObserver()
    public static let ringCapacity = 300

    private var pipe: Pipe?
    private var originalStdout: Int32?
    private var originalStderr: Int32?
    private let bufferQueue = DispatchQueue(label: "io.userback.log-observer")
    private var ring: [String] = []

    private init() {}

    public func start() {
        guard pipe == nil else { return }

        let newPipe = Pipe()
        pipe = newPipe

        // Keep copies so stdout/stderr can be restored on stop.
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        dup2(newPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(newPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        let mirroredStdoutFD = originalStdout

        newPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            // Mirror captured output back to original stdout so Xcode console still shows logs.
            if let stdoutFD = mirroredStdoutFD {
                data.withUnsafeBytes { buffer in
                    guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    var bytesRemaining = buffer.count
                    var offset = 0

                    while bytesRemaining > 0 {
                        let written = write(stdoutFD, base.advanced(by: offset), bytesRemaining)
                        if written <= 0 { break }
                        bytesRemaining -= written
                        offset += written
                    }
                }
            }

            self?.ingest(data)
        }

        print("LogObserver started")
    }

    public func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil

        if let originalStdout {
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            self.originalStdout = nil
        }

        if let originalStderr {
            dup2(originalStderr, STDERR_FILENO)
            close(originalStderr)
            self.originalStderr = nil
        }

        pipe = nil
        clear()
        print("LogObserver stopped")
    }

    /// Returns buffered log lines and empties the ring. Safe to call from the main actor.
    public func drainMessages() -> [String] {
        bufferQueue.sync {
            let copy = ring
            ring.removeAll(keepingCapacity: true)
            return copy
        }
    }

    public func clear() {
        bufferQueue.sync {
            ring.removeAll(keepingCapacity: true)
        }
    }

    private func ingest(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }

        let messages = raw
            .split(whereSeparator: \.isNewline)
            .compactMap { prepare(String($0)) }

        guard !messages.isEmpty else { return }

        bufferQueue.async {
            for message in messages {
                if self.ring.count >= Self.ringCapacity {
                    self.ring.removeFirst(self.ring.count - Self.ringCapacity + 1)
                }
                self.ring.append(message)
            }
        }
    }

    /// Apple system logs that are not app-level diagnostics.
    private static let noiseNeedles = [
        "RemoteTextInput",
        "RTILog",
        "NSAutoresizingMaskLayoutConstraint",
        "NSLayoutConstraint",
        "Unable to simultaneously satisfy constraints",
        "UIViewAlertForUnsatisfiableConstraints",
        "Probably at least one of the constraints",
        "Will attempt to recover by breaking constraint",
        "UIConstraintBasedLayoutDebugging category on UIView",
        "_UIToolbarContentView",
        "_UIButtonBarStackView",
    ]

    private static let whitespaceRunRegex = try? NSRegularExpression(pattern: #"\s+"#)

    private func prepare(_ message: String) -> String? {
        // Avoid feedback loops from SDK/internal observer logs.
        if message.hasPrefix("UserbackSDK:") ||
            message.hasPrefix("LogObserver") ||
            message == "================" {
            return nil
        }

        if message.hasPrefix("OSLOG-") {
            return nil
        }

        // `.literal` skips the locale-aware normalisation that made this the most
        // expensive step in the reader; these needles are all plain ASCII.
        let isNoise = Self.noiseNeedles.contains { needle in
            message.range(of: needle, options: [.caseInsensitive, .literal]) != nil
        }
        if isNoise { return nil }

        var trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("  ") || trimmed.contains("\t") {
            trimmed = Self.collapseWhitespace(trimmed)
        }

        guard !trimmed.isEmpty else { return nil }

        let redacted = SecretRedactor.redact(trimmed)
        guard !redacted.isEmpty else { return nil }
        return redacted
    }

    private static func collapseWhitespace(_ input: String) -> String {
        guard let regex = whitespaceRunRegex else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: " ")
    }
}

#endif
