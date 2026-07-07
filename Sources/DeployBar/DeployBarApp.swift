import AppKit
import SwiftUI

@main
struct DeployBarApp: App {
    @StateObject private var store = ProjectStore()
    @StateObject private var executor = PipelineExecutor()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarQuickListView()
                .environmentObject(store)
                .environmentObject(executor)
                .onAppear {
                    executor.onHistory = { item in
                        store.addHistory(item)
                    }
                }
        } label: {
            Label("DeployBar", systemImage: executor.isRunning ? "arrow.triangle.2.circlepath.circle.fill" : "terminal")
        }
        .menuBarExtraStyle(.window)

        Window("DeployBar Configuration", id: "configuration") {
            RootPanelView(showConfiguration: true)
                .environmentObject(store)
                .environmentObject(executor)
                .frame(minWidth: 760, idealWidth: 900, minHeight: 680, idealHeight: 760)
                .onAppear {
                    executor.onHistory = { item in
                        store.addHistory(item)
                    }
                    centerConfigurationWindow()
                }
        }
        .defaultSize(width: 900, height: 760)
    }

    private func centerConfigurationWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "DeployBar Configuration" }),
                  let screen = window.screen ?? NSScreen.main else {
                return
            }

            let frame = window.frame
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.midY - frame.height / 2
            )
            window.setFrameOrigin(origin)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
