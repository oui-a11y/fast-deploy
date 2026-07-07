import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    private static let maxHistoryLogCharacters = 120_000

    @Published var projects: [DeployProject] = []
    @Published var history: [DeploymentHistoryItem] = []

    private let projectsURL: URL
    private let historyURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.supportDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        projectsURL = support.appendingPathComponent("projects.json")
        historyURL = support.appendingPathComponent("history.json")
        load()
    }

    private static var supportDirectoryName: String {
        #if DEBUG
        return "DeployBar-Debug"
        #else
        return Bundle.main.bundleIdentifier ?? "local.deploybar.app"
        #endif
    }

    func load() {
        if FileManager.default.fileExists(atPath: projectsURL.path) {
            let loadedProjects = loadJSON([DeployProject].self, from: projectsURL) ?? []
            projects = loadedProjects.map(VariableSanitizer.sanitize)
            if projects != loadedProjects {
                saveProjects()
            }
        } else {
            projects = []
        }
        history = loadJSON([DeploymentHistoryItem].self, from: historyURL) ?? []
    }

    func saveProjects() {
        saveJSON(projects, to: projectsURL)
    }

    func saveHistory() {
        saveJSON(history, to: historyURL)
    }

    func upsert(_ project: DeployProject) {
        let sanitizedProject = VariableSanitizer.sanitize(project)
        if let index = projects.firstIndex(where: { $0.id == sanitizedProject.id }) {
            projects[index] = sanitizedProject
        } else {
            projects.append(sanitizedProject)
        }
        saveProjects()
    }

    func deleteProject(_ project: DeployProject) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }

    func addHistory(_ item: DeploymentHistoryItem) {
        var cappedItem = item
        if cappedItem.log.count > Self.maxHistoryLogCharacters {
            cappedItem.log = String(cappedItem.log.suffix(Self.maxHistoryLogCharacters))
        }
        history.insert(cappedItem, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        saveHistory()
    }

    func deleteHistory(_ item: DeploymentHistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
