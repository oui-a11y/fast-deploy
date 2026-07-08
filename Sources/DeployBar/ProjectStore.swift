import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    private static let maxHistoryLogCharacters = 120_000

    @Published var projects: [DeployProject] = []
    @Published var history: [DeploymentHistoryRecord] = []

    private let projectsURL: URL
    private let historyURL: URL
    private let historyLogsURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.supportDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        projectsURL = support.appendingPathComponent("projects.json")
        historyURL = support.appendingPathComponent("history.json")
        historyLogsURL = support.appendingPathComponent("history-logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: historyLogsURL, withIntermediateDirectories: true)
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
        history = loadJSON([DeploymentHistoryRecord].self, from: historyURL) ?? []
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

        writeHistoryLog(cappedItem.log, for: cappedItem.id)
        history.insert(DeploymentHistoryRecord(item: cappedItem), at: 0)
        if history.count > 50 {
            let removedItems = history.dropFirst(50)
            for item in removedItems {
                deleteHistoryLog(for: item.id)
            }
            history = Array(history.prefix(50))
        }
        saveHistory()
    }

    func deleteHistory(_ item: DeploymentHistoryRecord) {
        history.removeAll { $0.id == item.id }
        deleteHistoryLog(for: item.id)
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        deleteAllHistoryLogs()
        saveHistory()
    }

    func loadHistoryLog(for item: DeploymentHistoryRecord) -> String {
        (try? String(contentsOf: historyLogURL(for: item.id), encoding: .utf8)) ?? ""
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

    private func historyLogURL(for id: UUID) -> URL {
        historyLogsURL.appendingPathComponent("\(id.uuidString).log")
    }

    private func writeHistoryLog(_ log: String, for id: UUID) {
        try? log.write(to: historyLogURL(for: id), atomically: true, encoding: .utf8)
    }

    private func deleteHistoryLog(for id: UUID) {
        try? FileManager.default.removeItem(at: historyLogURL(for: id))
    }

    private func deleteAllHistoryLogs() {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: historyLogsURL, includingPropertiesForKeys: nil) else {
            return
        }

        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
