import Foundation

enum VariableSanitizer {
    static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitize(_ variables: [String: String]) -> [String: String] {
        variables.reduce(into: [String: String]()) { result, pair in
            let key = trim(pair.key)
            guard !key.isEmpty else { return }
            result[key] = trim(pair.value)
        }
    }

    static func sanitize(_ project: DeployProject) -> DeployProject {
        var sanitized = project
        sanitized.name = trim(sanitized.name)
        sanitized.localPath = trim(sanitized.localPath)
        sanitized.environments = sanitized.environments.map { environment in
            var next = environment
            next.name = trim(next.name)
            next.variables = sanitize(next.variables)
            next.steps = next.steps.map { step in
                var nextStep = step
                nextStep.name = trim(nextStep.name)
                nextStep.workingDirectory = nextStep.workingDirectory.map(trim).flatMap { $0.isEmpty ? nil : $0 }
                return nextStep
            }
            return next
        }
        return sanitized
    }
}

