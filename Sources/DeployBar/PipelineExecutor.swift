import Foundation

@MainActor
final class PipelineExecutor: ObservableObject {
    private static let maxLiveLogCharacters = 200_000

    @Published var isRunning = false
    @Published var activeTitle = "Idle"
    @Published var statuses: [StepRunStatus] = []
    @Published var log = ""
    @Published var activeProjectID: UUID?
    @Published var activeEnvironmentID: UUID?
    @Published private var recentResults: [String: Bool] = [:]

    private let runner = ShellCommandRunner()
    private var task: Task<Void, Never>?
    private var currentProject: DeployProject?
    private var currentEnvironment: DeployEnvironment?
    private var runStartedAt: Date?

    var onHistory: ((DeploymentHistoryItem) -> Void)?

    func deploy(project: DeployProject, environment: DeployEnvironment) {
        guard !isRunning else { return }

        currentProject = project
        currentEnvironment = environment
        activeProjectID = project.id
        activeEnvironmentID = environment.id
        runStartedAt = Date()
        isRunning = true
        activeTitle = "\(project.name) / \(environment.name)"
        log = ""
        statuses = environment.steps.map {
            StepRunStatus(id: $0.id, name: $0.name, state: $0.enabled ? .pending : .skipped, exitCode: nil)
        }

        task = Task {
            var succeeded = true
            appendLog("Starting \(project.name) / \(environment.name)\n")
            appendLog("Working directory: \(project.localPath)\n")

            for step in environment.steps {
                guard !Task.isCancelled else {
                    succeeded = false
                    appendLog("Deployment stopped by user.\n")
                    break
                }

                guard step.enabled else {
                    updateStatus(step.id, state: .skipped, exitCode: nil)
                    continue
                }

                updateStatus(step.id, state: .running, exitCode: nil)
                let renderedCommand = TemplateRenderer.render(command: step.command, project: project, environment: environment)
                let workingDirectory = step.workingDirectory?.isEmpty == false ? step.workingDirectory! : project.localPath
                appendLog("\n$ \(renderedCommand)\n")

                let exitCode = await runner.run(command: renderedCommand, workingDirectory: workingDirectory) { [weak self] text in
                    Task { @MainActor in
                        self?.appendLog(text)
                    }
                }

                if exitCode == 0 {
                    updateStatus(step.id, state: .succeeded, exitCode: exitCode)
                } else {
                    updateStatus(step.id, state: .failed, exitCode: exitCode)
                    succeeded = false
                    appendLog("Step failed with exit code \(exitCode).\n")
                    if step.stopOnFailure {
                        break
                    }
                }
            }

            finish(succeeded: succeeded)
        }
    }

    func stop() {
        runner.stop()
        task?.cancel()
    }

    func isActive(project: DeployProject, environment: DeployEnvironment) -> Bool {
        activeProjectID == project.id && activeEnvironmentID == environment.id
    }

    func recentResult(project: DeployProject, environment: DeployEnvironment) -> Bool? {
        recentResults[resultKey(projectID: project.id, environmentID: environment.id)]
    }

    var progressFraction: Double {
        guard !statuses.isEmpty else { return 0 }
        let completed = statuses.filter { status in
            status.state == .succeeded || status.state == .failed || status.state == .skipped
        }.count
        return Double(completed) / Double(statuses.count)
    }

    var progressText: String {
        guard !statuses.isEmpty else { return "Ready" }
        let completed = statuses.filter { status in
            status.state == .succeeded || status.state == .failed || status.state == .skipped
        }.count
        return "\(completed)/\(statuses.count)"
    }

    private func updateStatus(_ id: UUID, state: StepRunState, exitCode: Int32?) {
        guard let index = statuses.firstIndex(where: { $0.id == id }) else { return }
        statuses[index].state = state
        statuses[index].exitCode = exitCode
    }

    private func appendLog(_ text: String) {
        log += LogRedactor.redact(text)
        if log.count > Self.maxLiveLogCharacters {
            log = String(log.suffix(Self.maxLiveLogCharacters))
        }
    }

    private func finish(succeeded: Bool) {
        let finishedAt = Date()
        let summary = succeeded ? "Succeeded" : "Failed"
        appendLog("\n\(summary).\n")

        if let project = currentProject, let environment = currentEnvironment, let startedAt = runStartedAt {
            recentResults[resultKey(projectID: project.id, environmentID: environment.id)] = succeeded
            onHistory?(
                DeploymentHistoryItem(
                    projectName: project.name,
                    environmentName: environment.name,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    succeeded: succeeded,
                    summary: summary,
                    log: log
                )
            )
        }

        isRunning = false
        activeTitle = "Idle"
        activeProjectID = nil
        activeEnvironmentID = nil
        task = nil
    }

    private func resultKey(projectID: UUID, environmentID: UUID) -> String {
        "\(projectID.uuidString)-\(environmentID.uuidString)"
    }
}
