import AppKit
import SwiftUI

struct MenuBarQuickListView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var executor: PipelineExecutor
    @Environment(\.openWindow) private var openWindow
    @State private var showProdConfirmation = false
    @State private var pendingDeployment: MenuPendingDeployment?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if shortcuts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(shortcuts) { shortcut in
                            ShortcutRow(
                                shortcut: shortcut,
                                isRunning: executor.isRunning,
                                isActive: executor.isActive(project: shortcut.project, environment: shortcut.environment),
                                progress: executor.progressFraction,
                                progressText: executor.progressText,
                                recentResult: executor.recentResult(project: shortcut.project, environment: shortcut.environment),
                                action: { requestDeploy(shortcut) },
                                stopAction: executor.stop
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(height: shortcutListHeight)
                .id(shortcuts.map(\.id).joined(separator: "|"))
            }

            Divider()

            footer
        }
        .frame(width: 320)
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

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DeployBarTheme.accent)
                Image(systemName: executor.isRunning ? "arrow.triangle.2.circlepath" : "terminal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("DeployBar")
                    .font(.subheadline.weight(.semibold))
                Text(executor.isRunning ? "Deployment running" : "\(shortcuts.count) deploy targets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if executor.isRunning {
                StatusPill(title: "Running", systemImage: "bolt.horizontal.fill", color: DeployBarTheme.warning)
            } else {
                StatusPill(title: "Ready", systemImage: "checkmark.circle.fill", color: DeployBarTheme.success)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No projects configured")
                .font(.subheadline.weight(.semibold))
            Button {
                openConfigurationWindow()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
    }

    private var footer: some View {
        HStack {
            Button {
                openConfigurationWindow()
            } label: {
                Label("Configure", systemImage: "slider.horizontal.3")
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var shortcuts: [DeployShortcut] {
        store.projects.flatMap { project in
            project.environments.map { environment in
                DeployShortcut(project: project, environment: environment)
            }
        }
    }

    private var shortcutListHeight: CGFloat {
        let rowHeight: CGFloat = CGFloat(shortcuts.count) * 52
        let padding: CGFloat = 16
        return min(390, max(96, rowHeight + padding))
    }

    private func requestDeploy(_ shortcut: DeployShortcut) {
        if requiresConfirmation(shortcut.environment) {
            pendingDeployment = MenuPendingDeployment(project: shortcut.project, environment: shortcut.environment)
            showProdConfirmation = true
        } else {
            executor.deploy(project: shortcut.project, environment: shortcut.environment)
        }
    }

    private func requiresConfirmation(_ environment: DeployEnvironment) -> Bool {
        let name = environment.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name == "prod" || name == "production"
    }

    private func openConfigurationWindow() {
        openWindow(id: "configuration")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct MenuPendingDeployment: Identifiable {
    let id = UUID()
    let project: DeployProject
    let environment: DeployEnvironment
}

private struct DeployShortcut: Identifiable {
    let project: DeployProject
    let environment: DeployEnvironment

    var id: String {
        "\(project.id.uuidString)-\(environment.id.uuidString)"
    }

    var title: String {
        "\(project.name) / \(environment.name)"
    }

    var enabledStepCount: Int {
        environment.steps.filter(\.enabled).count
    }

    var isProduction: Bool {
        let name = environment.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name == "prod" || name == "production"
    }
}

private struct ProjectShortcutSection: View {
    let project: DeployProject
    let isRunning: Bool
    let activeProjectID: UUID?
    let activeEnvironmentID: UUID?
    let progress: Double
    let progressText: String
    let deployAction: (DeployEnvironment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(DeployBarTheme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text(project.localPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("\(project.environments.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(project.environments) { environment in
                    ShortcutRow(
                        shortcut: DeployShortcut(project: project, environment: environment),
                        isRunning: isRunning,
                        isActive: activeProjectID == project.id && activeEnvironmentID == environment.id,
                        progress: progress,
                        progressText: progressText,
                        recentResult: nil,
                        action: { deployAction(environment) },
                        stopAction: {}
                    )
                }
            }
        }
        .padding(10)
        .deploySurface()
    }
}

private struct ShortcutRow: View {
    let shortcut: DeployShortcut
    let isRunning: Bool
    let isActive: Bool
    let progress: Double
    let progressText: String
    let recentResult: Bool?
    let action: () -> Void
    let stopAction: () -> Void

    var body: some View {
        Button(action: isActive ? stopAction : action) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.14))
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(shortcut.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(isActive ? DeployBarTheme.accent : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isActive {
                    HStack(spacing: 8) {
                        Text(progressText)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DeployBarTheme.accent)
                        Image(systemName: "stop.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 24)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                } else if let recentResult {
                    Image(systemName: recentResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(recentResult ? DeployBarTheme.success : DeployBarTheme.danger)
                } else {
                    Image(systemName: shortcut.enabledStepCount == 0 ? "minus.circle" : "play.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(shortcut.enabledStepCount == 0 ? .secondary : DeployBarTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 46)
            .background(alignment: .leading) {
                if isActive {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DeployBarTheme.accent.opacity(0.16))
                            .frame(width: proxy.size.width * max(0.04, min(progress, 1)))
                            .animation(.easeInOut(duration: 0.22), value: progress)
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled((isRunning && !isActive) || shortcut.enabledStepCount == 0)
        .deploySurface(radius: 7, fill: DeployBarTheme.panelRaised)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DeployBarTheme.accent.opacity(0.55), lineWidth: 1)
            }
        }
        .opacity((isRunning && !isActive) || shortcut.enabledStepCount == 0 ? 0.55 : 1)
    }

    private var subtitle: String {
        if isActive {
            return "Running deployment"
        }
        if shortcut.enabledStepCount == 0 {
            return "No enabled steps"
        }
        if let recentResult {
            return recentResult ? "Last run succeeded" : "Last run failed"
        }
        return "\(shortcut.enabledStepCount) enabled steps"
    }

    private var iconName: String {
        if isActive {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
        return shortcut.isProduction ? "exclamationmark.triangle.fill" : "play.circle.fill"
    }

    private var iconColor: Color {
        if isActive {
            return DeployBarTheme.accent
        }
        return shortcut.isProduction ? DeployBarTheme.warning : DeployBarTheme.success
    }
}
