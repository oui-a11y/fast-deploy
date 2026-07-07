import AppKit

enum FolderPicker {
    @MainActor
    static func chooseFolder(
        title: String,
        message: String,
        prompt: String,
        initialPath: String? = nil,
        completion: @escaping (String) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        if let initialPath, !initialPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: initialPath, isDirectory: true)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        NSApp.activate(ignoringOtherApps: true)

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                completion(url.path)
            }
        }
    }
}

