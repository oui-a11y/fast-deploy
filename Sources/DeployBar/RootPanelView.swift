import SwiftUI

struct RootPanelView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var executor: PipelineExecutor
    @State private var selection = PanelSection.configuration

    init(showConfiguration: Bool = false) {
        _selection = State(initialValue: showConfiguration ? .configuration : .monitor)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(DeployBarTheme.accent)
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text("DeployBar")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if executor.isRunning {
                    Button(role: .destructive) {
                        executor.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .labelStyle(.titleAndIcon)
                } else {
                    StatusPill(title: "Ready", systemImage: "checkmark.circle.fill", color: DeployBarTheme.success)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HStack {
                Picker("", selection: $selection) {
                    Label("Configuration", systemImage: "slider.horizontal.3").tag(PanelSection.configuration)
                    Label("Monitor", systemImage: "waveform.path.ecg").tag(PanelSection.monitor)
                    Label("History", systemImage: "clock").tag(PanelSection.history)
                }
                .pickerStyle(.segmented)
                .frame(width: 360)

                Spacer()

                Text(windowHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch selection {
                case .configuration:
                    ProjectManagerView()
                case .history:
                    HistoryView()
                case .monitor:
                    DeployPanelView {
                        selection = .configuration
                    }
                }
            }
            .background(DeployBarTheme.background)
        }
    }

    private var subtitle: String {
        if executor.isRunning {
            return executor.activeTitle
        }

        switch selection {
        case .configuration:
            return "Configuration workbench"
        case .monitor:
            return "Run monitor"
        case .history:
            return "\(store.history.count) deployment records"
        }
    }

    private var windowHint: String {
        switch selection {
        case .configuration:
            return "Projects, environments, variables, and steps"
        case .monitor:
            return executor.isRunning ? executor.progressText : "Watch deploy output"
        case .history:
            return "Review previous runs"
        }
    }
}

private enum PanelSection: Hashable {
    case configuration
    case monitor
    case history
}
