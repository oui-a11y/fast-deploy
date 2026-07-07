import Foundation

enum TemplateRenderer {
    static func render(command: String, project: DeployProject, environment: DeployEnvironment) -> String {
        var values = VariableSanitizer.sanitize(environment.variables)
        values["projectName"] = VariableSanitizer.trim(project.name)
        values["projectPath"] = VariableSanitizer.trim(project.localPath)
        values["env"] = VariableSanitizer.trim(environment.name)
        values["timestamp"] = timestamp()
        values["date"] = date()

        var rendered = command
        for _ in 0..<3 {
            var changed = false
            for (key, value) in values {
                let next = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
                changed = changed || next != rendered
                rendered = next
            }
            if !changed {
                break
            }
        }
        return rendered
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func date() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
