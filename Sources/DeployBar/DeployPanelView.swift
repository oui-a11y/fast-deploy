import SwiftUI

struct DeployPanelView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var executor: PipelineExecutor
    @State private var showProdConfirmation = false
    @State private var pendingDeployment: PendingDeployment?
    let configureAction: () -> Void

    init(configureAction: @escaping () -> Void = {}) {
        self.configureAction = configureAction
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.projects.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView("No Deploy Shortcuts", systemImage: "folder.badge.plus", description: Text("Create a project configuration first."))
                    Button {
                        configureAction()
                    } label: {
                        Label("Open Configuration", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderedProminent)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AppSectionHeader(
                            title: "Deploy Shortcuts",
                            subtitle: "Click a configured environment to deploy",
                            systemImage: "bolt.fill"
                        )

                        Button {
                            configureAction()
                        } label: {
                            Label("Configure", systemImage: "slider.horizontal.3")
                        }
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.projects) { project in
                                QuickDeployProjectGroup(
                                    project: project,
                                    isRunning: executor.isRunning,
                                    deployAction: startDeploy(project:environment:)
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .frame(maxHeight: 230)
                }
                .padding(14)

                Divider()

                RunStatusView()
            }
        }
        .confirmationDialog("Deploy to production?", isPresented: $showProdConfirmation, titleVisibility: .visible) {
            Button("Deploy Production", role: .destructive) {
                if let pendingDeployment {
                    executor.deploy(project: pendingDeployment.project, environment: pendingDeployment.environment)
                }
                pendingDeployment = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeployment = nil
            }
        } message: {
            Text("You are deploying \(pendingDeployment?.project.name ?? "this project") to \(pendingDeployment?.environment.name ?? "prod").")
        }
    }

    private func startDeploy(project: DeployProject, environment: DeployEnvironment) {
        if requiresConfirmation(environment) {
            pendingDeployment = PendingDeployment(project: project, environment: environment)
            showProdConfirmation = true
        } else {
            executor.deploy(project: project, environment: environment)
        }
    }

    private func requiresConfirmation(_ environment: DeployEnvironment) -> Bool {
        let name = environment.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name == "prod" || name == "production"
    }
}

private struct PendingDeployment: Identifiable {
    let id = UUID()
    let project: DeployProject
    let environment: DeployEnvironment
}

struct QuickDeployProjectGroup: View {
    let project: DeployProject
    let isRunning: Bool
    let deployAction: (DeployProject, DeployEnvironment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(DeployBarTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(project.localPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(project.environments) { environment in
                    QuickDeployEnvironmentButton(
                        project: project,
                        environment: environment,
                        isRunning: isRunning,
                        deployAction: deployAction
                    )
                }
            }
        }
        .padding(10)
        .deploySurface()
    }
}

struct QuickDeployEnvironmentButton: View {
    let project: DeployProject
    let environment: DeployEnvironment
    let isRunning: Bool
    let deployAction: (DeployProject, DeployEnvironment) -> Void

    private var enabledStepCount: Int {
        environment.steps.filter(\.enabled).count
    }

    private var isProduction: Bool {
        let name = environment.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name == "prod" || name == "production"
    }

    var body: some View {
        Button {
            deployAction(project, environment)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isProduction ? "exclamationmark.triangle.fill" : "play.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isProduction ? DeployBarTheme.warning : DeployBarTheme.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("\(enabledStepCount) steps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRunning || enabledStepCount == 0)
        .deploySurface(fill: DeployBarTheme.panelRaised)
        .opacity(isRunning || enabledStepCount == 0 ? 0.55 : 1)
    }
}

struct DeployControlCard: View {
    let selectedProject: DeployProject?
    let selectedEnvironment: DeployEnvironment?
    let projectSelection: Binding<DeployProject.ID>
    let environmentSelection: Binding<DeployEnvironment.ID>
    let projects: [DeployProject]
    let isRunning: Bool
    let deployAction: () -> Void

    private var enabledStepCount: Int {
        selectedEnvironment?.steps.filter(\.enabled).count ?? 0
    }

    private var variableCount: Int {
        selectedEnvironment?.variables.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AppSectionHeader(
                    title: "Deploy Workspace",
                    subtitle: selectedProject?.localPath ?? "Choose a project and environment",
                    systemImage: "shippingbox"
                )

                Button(action: deployAction) {
                    Label(isRunning ? "Running" : "Deploy", systemImage: isRunning ? "hourglass" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DeployBarTheme.accent)
                .disabled(isRunning || selectedEnvironment == nil)
            }

            HStack(spacing: 10) {
                Picker("Project", selection: projectSelection) {
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }

                Picker("Environment", selection: environmentSelection) {
                    ForEach(selectedProject?.environments ?? []) { environment in
                        Text(environment.name).tag(environment.id)
                    }
                }
                .frame(width: 132)
            }

            HStack(spacing: 8) {
                MetadataChip(title: "Steps", value: "\(enabledStepCount) enabled", systemImage: "checklist")
                MetadataChip(title: "Variables", value: "\(variableCount) mapped", systemImage: "curlybraces")
                MetadataChip(title: "Target", value: selectedEnvironment?.name ?? "None", systemImage: "scope")
            }
        }
        .padding(12)
        .deploySurface()
    }
}

struct CommandPreviewCard: View {
    let steps: [(String, String)]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if steps.isEmpty {
                    Text("No enabled steps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 9) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(DeployBarTheme.accent, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.0)
                                    .font(.caption.weight(.semibold))
                                Text(item.1)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                        .deploySurface(fill: DeployBarTheme.panelRaised)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                AppSectionHeader(title: "Command Preview", subtitle: "Secrets are redacted before display", systemImage: "doc.text.magnifyingglass")
                StatusPill(title: "\(steps.count)", systemImage: "terminal", color: DeployBarTheme.cyan)
            }
        }
        .padding(12)
        .deploySurface()
    }
}

struct RunStatusView: View {
    @EnvironmentObject private var executor: PipelineExecutor
    @State private var statusHeight: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    AppSectionHeader(
                        title: executor.isRunning ? "Run in Progress" : "Run Monitor",
                        subtitle: executor.activeTitle,
                        systemImage: executor.isRunning ? "arrow.triangle.2.circlepath" : "waveform.path.ecg"
                    )

                    StatusPill(
                        title: progressSummary,
                        systemImage: executor.isRunning ? "bolt.horizontal.fill" : "checkmark",
                        color: executor.isRunning ? DeployBarTheme.warning : DeployBarTheme.success
                    )
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        if executor.statuses.isEmpty {
                            Text("Deployment steps will appear here when a run starts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        } else {
                            ForEach(executor.statuses) { status in
                                StatusRow(status: status)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(height: statusHeight)
            }
            .padding(14)

            ResizeHandle { delta in
                statusHeight = min(260, max(72, statusHeight + delta))
            }

            VStack(spacing: 0) {
                HStack {
                    Label("Console", systemImage: "terminal")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(executor.log.isEmpty ? "Idle" : "\(executor.log.count) chars")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.bar)

                ConsoleTextView(text: executor.log, placeholder: "Logs will appear here.")
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var progressSummary: String {
        guard !executor.statuses.isEmpty else { return "Ready" }
        let complete = executor.statuses.filter { status in
            status.state == .succeeded || status.state == .failed || status.state == .skipped
        }.count
        return "\(complete)/\(executor.statuses.count)"
    }
}

struct ResizeHandle: View {
    let onDrag: (CGFloat) -> Void
    @State private var isDragging = false
    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(isDragging ? DeployBarTheme.accent.opacity(0.35) : DeployBarTheme.border)
            .frame(height: 8)
            .overlay {
                Capsule()
                    .fill(Color.secondary.opacity(isDragging ? 0.75 : 0.35))
                    .frame(width: 44, height: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let delta = value.translation.height - lastTranslation
                        lastTranslation = value.translation.height
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastTranslation = 0
                    }
            )
            .help("Drag to resize console")
    }
}

struct StatusRow: View {
    let status: StepRunStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon(for: status.state))
                .foregroundStyle(color(for: status.state))
                .frame(width: 20)

            Text(status.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(status.state.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let exitCode = status.exitCode, exitCode != 0 {
                Text("\(exitCode)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DeployBarTheme.danger)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DeployBarTheme.danger.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .deploySurface(fill: DeployBarTheme.panelRaised)
    }

    private func icon(for state: StepRunState) -> String {
        switch state {
        case .pending: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private func color(for state: StepRunState) -> Color {
        switch state {
        case .pending: return .secondary
        case .running: return DeployBarTheme.warning
        case .succeeded: return DeployBarTheme.success
        case .failed: return DeployBarTheme.danger
        case .skipped: return .secondary
        }
    }
}
