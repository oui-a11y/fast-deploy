import Foundation

struct DeployProject: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var localPath: String
    var environments: [DeployEnvironment]

    static let starter = DeployProject(
        name: "Example Web App",
        localPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Projects/example-web").path,
        environments: [
            DeployEnvironment(
                name: "dev",
                variables: [
                    "server": "dev-server",
                    "remotePath": "/var/www/example-web"
                ],
                steps: [
                    DeployStep(name: "Install dependencies", command: "pnpm install"),
                    DeployStep(name: "Build", command: "pnpm build"),
                    DeployStep(name: "Upload dist", command: "rsync -avz ./dist/ {{server}}:{{remotePath}}/")
                ]
            )
        ]
    )
}

struct DeployEnvironment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var variables: [String: String]
    var steps: [DeployStep]
}

struct DeployStep: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var workingDirectory: String?
    var enabled: Bool = true
    var stopOnFailure: Bool = true
    var timeoutSeconds: Int?
}

struct DeploymentHistoryItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var projectName: String
    var environmentName: String
    var startedAt: Date
    var finishedAt: Date
    var succeeded: Bool
    var summary: String
    var log: String
}

struct DeploymentHistoryRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var projectName: String
    var environmentName: String
    var startedAt: Date
    var finishedAt: Date
    var succeeded: Bool
    var summary: String
    var logCharacterCount: Int?

    init(
        id: UUID = UUID(),
        projectName: String,
        environmentName: String,
        startedAt: Date,
        finishedAt: Date,
        succeeded: Bool,
        summary: String,
        logCharacterCount: Int? = nil
    ) {
        self.id = id
        self.projectName = projectName
        self.environmentName = environmentName
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.succeeded = succeeded
        self.summary = summary
        self.logCharacterCount = logCharacterCount
    }

    init(item: DeploymentHistoryItem) {
        self.init(
            id: item.id,
            projectName: item.projectName,
            environmentName: item.environmentName,
            startedAt: item.startedAt,
            finishedAt: item.finishedAt,
            succeeded: item.succeeded,
            summary: item.summary,
            logCharacterCount: item.log.count
        )
    }
}

enum StepRunState: String, Equatable {
    case pending = "Pending"
    case running = "Running"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case skipped = "Skipped"
}

struct StepRunStatus: Identifiable, Equatable {
    var id: UUID
    var name: String
    var state: StepRunState
    var exitCode: Int32?
}
