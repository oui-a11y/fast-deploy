import SwiftUI

struct ProjectManagerView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var selectedProjectID: DeployProject.ID?
    @State private var draft = DeployProject(name: "", localPath: "", environments: [])

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Projects", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    TemplateMenu(createProject: createProject)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                if store.projects.isEmpty {
                    ContentUnavailableView("No Projects", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedProjectID) {
                        ForEach(store.projects) { project in
                            ProjectSidebarRow(project: project)
                                .tag(project.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(width: 190)
            .background(.bar)

            Divider()

            if selectedProjectID == nil && store.projects.isEmpty {
                ContentUnavailableView("Create a Project", systemImage: "hammer", description: Text("Use New to start from a deployment template."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    ProjectEditorView(project: $draft)
                        .padding(14)
                }
                .onChange(of: selectedProjectID) { _, _ in
                    loadSelection()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                TemplateMenu(createProject: createProject)

                Button(role: .destructive) {
                    if let project = store.projects.first(where: { $0.id == selectedProjectID }) {
                        store.deleteProject(project)
                        selectedProjectID = store.projects.first?.id
                        loadSelection()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedProjectID == nil)

                Spacer()

                Button {
                    store.upsert(draft)
                    selectedProjectID = draft.id
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
        }
        .onAppear {
            selectedProjectID = selectedProjectID ?? store.projects.first?.id
            loadSelection()
        }
    }

    private func loadSelection() {
        if let project = store.projects.first(where: { $0.id == selectedProjectID }) {
            draft = project
        }
    }

    private func createProject(template: ProjectTemplate) {
        FolderPicker.chooseFolder(
            title: "Choose Project Folder",
            message: "Choose the local source-code folder for this deployment project.",
            prompt: "Create Project"
        ) { path in
            let project = template.makeProject(path: path)
            store.upsert(project)
            selectedProjectID = project.id
            draft = project
        }
    }
}

struct TemplateMenu: View {
    let createProject: (ProjectTemplate) -> Void

    var body: some View {
        Menu {
            ForEach(ProjectTemplate.allCases) { template in
                Button(template.title) {
                    createProject(template)
                }
            }
        } label: {
            Label("New", systemImage: "plus")
        }
    }
}

struct ProjectSidebarRow: View {
    let project: DeployProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Label("\(project.environments.count)", systemImage: "scope")
                Label("\(project.environments.flatMap(\.steps).count)", systemImage: "checklist")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ProjectEditorView: View {
    @Binding var project: DeployProject
    @State private var selectedEnvironmentID: DeployEnvironment.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProjectSettingsCard(project: $project, chooseProjectPath: chooseProjectPath)

            VStack(alignment: .leading, spacing: 12) {
                EnvironmentTabBar(
                    project: $project,
                    selectedEnvironmentID: $selectedEnvironmentID,
                    addEnvironment: addEnvironment
                )

                if let index = selectedEnvironmentIndex {
                    EnvironmentWorkbench(
                        environment: $project.environments[index],
                        deleteEnvironment: deleteSelectedEnvironment
                    )
                } else {
                    ContentUnavailableView("No Environment", systemImage: "scope", description: Text("Add an environment to configure deploy steps."))
                        .frame(maxWidth: .infinity, minHeight: 420)
                }
            }
            .padding(12)
            .deploySurface()
        }
        .onAppear {
            ensureEnvironmentSelection()
        }
        .onChange(of: project.id) { _, _ in
            selectedEnvironmentID = project.environments.first?.id
        }
        .onChange(of: project.environments.map(\.id)) { _, _ in
            ensureEnvironmentSelection()
        }
    }

    private var selectedEnvironmentIndex: Int? {
        let id = selectedEnvironmentID ?? project.environments.first?.id
        return project.environments.firstIndex { $0.id == id }
    }

    private func chooseProjectPath() {
        FolderPicker.chooseFolder(
            title: "Choose Project Folder",
            message: "Choose the local source-code folder for this project.",
            prompt: "Choose",
            initialPath: project.localPath
        ) { path in
            project.localPath = path
        }
    }

    private func addEnvironment() {
        let environment = DeployEnvironment(name: "dev", variables: [:], steps: [])
        project.environments.append(environment)
        selectedEnvironmentID = environment.id
    }

    private func deleteSelectedEnvironment() {
        guard let id = selectedEnvironmentID else { return }
        project.environments.removeAll { $0.id == id }
        selectedEnvironmentID = project.environments.first?.id
    }

    private func ensureEnvironmentSelection() {
        guard !project.environments.isEmpty else {
            selectedEnvironmentID = nil
            return
        }

        if let selectedEnvironmentID,
           project.environments.contains(where: { $0.id == selectedEnvironmentID }) {
            return
        }

        selectedEnvironmentID = project.environments.first?.id
    }
}

struct ProjectSettingsCard: View {
    @Binding var project: DeployProject
    let chooseProjectPath: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AppSectionHeader(title: "Project", subtitle: project.localPath, systemImage: "shippingbox")

                HStack(spacing: 8) {
                    MetadataChip(title: "Envs", value: "\(project.environments.count)", systemImage: "scope")
                    MetadataChip(title: "Steps", value: "\(project.environments.flatMap(\.steps).count)", systemImage: "checklist")
                }
                .frame(width: 230)
            }

            HStack(spacing: 8) {
                TextField("Name", text: $project.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)
                TextField("Local path", text: $project.localPath)
                    .textFieldStyle(.roundedBorder)
                Button(action: chooseProjectPath) {
                    Image(systemName: "folder")
                }
                .help("Choose project folder")
            }
        }
        .padding(12)
        .deploySurface()
    }
}

struct EnvironmentTabBar: View {
    @Binding var project: DeployProject
    @Binding var selectedEnvironmentID: DeployEnvironment.ID?
    let addEnvironment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Environments", systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: addEnvironment) {
                    Image(systemName: "plus")
                }
                .help("Add environment")
            }

            if project.environments.isEmpty {
                Text("No environments yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .deploySurface(fill: DeployBarTheme.panelRaised)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(project.environments) { environment in
                            EnvironmentTab(
                                environment: environment,
                                isSelected: selectedEnvironmentID == environment.id
                            ) {
                                selectedEnvironmentID = environment.id
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct EnvironmentTab: View {
    let environment: DeployEnvironment
    let isSelected: Bool
    let action: () -> Void

    private var enabledStepCount: Int {
        environment.steps.filter(\.enabled).count
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "scope")
                    .foregroundStyle(isSelected ? DeployBarTheme.accent : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(environment.name.isEmpty ? "Environment" : environment.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label("\(enabledStepCount)/\(environment.steps.count)", systemImage: "checklist")
                        Label("\(environment.variables.count)", systemImage: "curlybraces")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 150, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .deploySurface(fill: isSelected ? DeployBarTheme.accent.opacity(0.10) : DeployBarTheme.panelRaised)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DeployBarTheme.accent.opacity(0.45), lineWidth: 1)
            }
        }
    }
}

struct EnvironmentSidebar: View {
    @Binding var project: DeployProject
    @Binding var selectedEnvironmentID: DeployEnvironment.ID?
    let addEnvironment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Environments", systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: addEnvironment) {
                    Image(systemName: "plus")
                }
                .help("Add environment")
            }

            if project.environments.isEmpty {
                Text("No environments yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .deploySurface(fill: DeployBarTheme.panelRaised)
            } else {
                VStack(spacing: 7) {
                    ForEach(project.environments) { environment in
                        EnvironmentSidebarRow(
                            environment: environment,
                            isSelected: selectedEnvironmentID == environment.id
                        ) {
                            selectedEnvironmentID = environment.id
                        }
                    }
                }
            }
        }
    }
}

struct EnvironmentSidebarRow: View {
    let environment: DeployEnvironment
    let isSelected: Bool
    let action: () -> Void

    private var enabledStepCount: Int {
        environment.steps.filter(\.enabled).count
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(environment.name.isEmpty ? "Environment" : environment.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DeployBarTheme.accent : .secondary)
                }

                HStack(spacing: 8) {
                    Label("\(enabledStepCount)/\(environment.steps.count)", systemImage: "checklist")
                    Label("\(environment.variables.count)", systemImage: "curlybraces")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .deploySurface(radius: 7, fill: isSelected ? DeployBarTheme.accent.opacity(0.10) : DeployBarTheme.panelRaised)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DeployBarTheme.accent.opacity(0.45), lineWidth: 1)
            }
        }
    }
}

struct EnvironmentWorkbench: View {
    @Binding var environment: DeployEnvironment
    let deleteEnvironment: () -> Void
    @State private var selectedTab = EnvironmentEditorTab.steps

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView(selection: $selectedTab) {
                StepListEditorView(steps: $environment.steps)
                    .padding(10)
                    .tabItem {
                        Label("Steps", systemImage: "terminal")
                    }
                    .tag(EnvironmentEditorTab.steps)

                VariableTabView(variables: $environment.variables)
                    .padding(10)
                    .tabItem {
                        Label("Variables", systemImage: "curlybraces")
                    }
                    .tag(EnvironmentEditorTab.variables)

                EnvironmentSettingsTabView(
                    environment: $environment,
                    deleteEnvironment: deleteEnvironment
                )
                .padding(10)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(EnvironmentEditorTab.settings)
            }
            .frame(minHeight: 560)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private enum EnvironmentEditorTab: Hashable {
    case steps
    case variables
    case settings
}

struct EnvironmentSettingsTabView: View {
    @Binding var environment: DeployEnvironment
    let deleteEnvironment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MetadataChip(title: "Enabled Steps", value: "\(environment.steps.filter(\.enabled).count)/\(environment.steps.count)", systemImage: "checklist")
                MetadataChip(title: "Variables", value: "\(environment.variables.count)", systemImage: "curlybraces")
            }

            VStack(alignment: .leading, spacing: 10) {
                AppSectionHeader(
                    title: "Environment Settings",
                    subtitle: "This name appears in the menu-bar deploy list.",
                    systemImage: "scope"
                )

                TextField("Environment name", text: $environment.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
            }
            .padding(12)
            .deploySurface(fill: DeployBarTheme.panelRaised)

            VStack(alignment: .leading, spacing: 10) {
                AppSectionHeader(
                    title: "Danger Zone",
                    subtitle: "Delete this environment and all of its steps.",
                    systemImage: "exclamationmark.triangle"
                )

                Button(role: .destructive, action: deleteEnvironment) {
                    Label("Delete Environment", systemImage: "trash")
                }
            }
            .padding(12)
            .deploySurface(fill: DeployBarTheme.panelRaised)

            Spacer(minLength: 0)
        }
    }
}

struct VariableTabView: View {
    @Binding var variables: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MetadataChip(title: "Variables", value: "\(variables.count)", systemImage: "curlybraces")
                MetadataChip(title: "Usage", value: "{{key}}", systemImage: "textformat")
            }

            VariableEditorView(variables: $variables)
                .padding(12)
                .deploySurface(fill: DeployBarTheme.panelRaised)

            Spacer(minLength: 0)
        }
    }
}

struct VariableEditorView: View {
    @Binding var variables: [String: String]
    @State private var newKey = ""
    @State private var newValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Variables", systemImage: "curlybraces")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(variables.keys.sorted(), id: \.self) { key in
                HStack(spacing: 8) {
                    Text(key)
                        .font(.caption.monospaced())
                        .frame(width: 110, alignment: .leading)
                    TextField("Value", text: Binding(
                        get: { variables[key] ?? "" },
                        set: { variables[key] = VariableSanitizer.trim($0) }
                    ))
                    Button {
                        variables.removeValue(forKey: key)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField("key", text: $newKey)
                TextField("value", text: $newValue)
                Button {
                    let key = VariableSanitizer.trim(newKey)
                    guard !key.isEmpty else { return }
                    variables[key] = VariableSanitizer.trim(newValue)
                    newKey = ""
                    newValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StepListEditorView: View {
    @Binding var steps: [DeployStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Command Steps", systemImage: "terminal")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    steps.append(DeployStep(name: "New Step", command: "echo hello"))
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
            }

            if steps.isEmpty {
                Text("Add the shell commands that should run for this environment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .deploySurface(fill: DeployBarTheme.panelRaised)
            } else {
                ForEach(Array($steps.enumerated()), id: \.element.id) { index, $step in
                    StepEditorCard(
                        index: index,
                        step: $step,
                        steps: $steps
                    )
                }
            }
        }
    }
}

struct StepEditorCard: View {
    let index: Int
    @Binding var step: DeployStep
    @Binding var steps: [DeployStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(step.enabled ? DeployBarTheme.accent : Color.secondary, in: Circle())

                TextField("Step name", text: $step.name)
                    .textFieldStyle(.roundedBorder)

                Toggle("Enabled", isOn: $step.enabled)
                    .toggleStyle(.checkbox)

                Toggle("Stop on failure", isOn: $step.stopOnFailure)
                    .toggleStyle(.checkbox)

                StepMoveButtons(steps: $steps, stepID: step.id)

                Button(role: .destructive) {
                    steps.removeAll { $0.id == step.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Delete step")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Command", systemImage: "terminal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(step.enabled ? "Will run" : "Skipped")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(step.enabled ? DeployBarTheme.success : .secondary)
                }

                TextEditor(text: $step.command)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25))
                    }
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                TextField("Working directory override", text: Binding(
                    get: { step.workingDirectory ?? "" },
                    set: { step.workingDirectory = $0.isEmpty ? nil : $0 }
                ))
                .font(.caption)
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .deploySurface(fill: step.enabled ? DeployBarTheme.panelRaised : DeployBarTheme.panel)
    }
}

struct StepMoveButtons: View {
    @Binding var steps: [DeployStep]
    let stepID: UUID

    var body: some View {
        HStack(spacing: 4) {
            Button {
                move(offset: -1)
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(!canMove(offset: -1))
            .help("Move step up")

            Button {
                move(offset: 1)
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .disabled(!canMove(offset: 1))
            .help("Move step down")
        }
    }

    private func canMove(offset: Int) -> Bool {
        guard let index = steps.firstIndex(where: { $0.id == stepID }) else { return false }
        let target = index + offset
        return steps.indices.contains(target)
    }

    private func move(offset: Int) {
        guard let index = steps.firstIndex(where: { $0.id == stepID }) else { return }
        let target = index + offset
        guard steps.indices.contains(target) else { return }
        let item = steps.remove(at: index)
        steps.insert(item, at: target)
    }
}
