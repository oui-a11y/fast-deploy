import Foundation

final class ShellCommandRunner {
    private let lock = NSLock()
    private var currentProcess: Process?

    func run(command: String, workingDirectory: String, onOutput: @escaping (String) -> Void) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", ShellEnvironment.wrappedCommand(command)]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            process.environment = ShellEnvironment.environment()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let outputHandle = pipe.fileHandleForReading
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                onOutput(text)
            }

            process.terminationHandler = { [weak self] terminated in
                outputHandle.readabilityHandler = nil
                self?.lock.lock()
                self?.currentProcess = nil
                self?.lock.unlock()
                continuation.resume(returning: terminated.terminationStatus)
            }

            do {
                lock.lock()
                currentProcess = process
                lock.unlock()
                try process.run()
            } catch {
                outputHandle.readabilityHandler = nil
                lock.lock()
                currentProcess = nil
                lock.unlock()
                onOutput("Failed to start command: \(error.localizedDescription)\n")
                continuation.resume(returning: 127)
            }
        }
    }

    func stop() {
        lock.lock()
        let process = currentProcess
        lock.unlock()
        process?.terminate()
    }
}
