import SwiftUI

@main
struct JARVISWorkstationApp: App {
    @StateObject private var installer = InstallerViewModel()
    @State private var showInstaller = false
    @State private var checkingRuntime = true
    @State private var ollamaAvailable = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showInstaller || checkingRuntime || !ollamaAvailable {
                    ContentView(onOpenWorkstation: {
                        Task {
                            await checkOllama()
                            if ollamaAvailable { showInstaller = false }
                        }
                    })
                    .environmentObject(installer)
                } else {
                    WorkstationView()
                }
            }
            .frame(minWidth: 900, minHeight: 640)
            .task { await checkOllama() }
            .onReceive(NotificationCenter.default.publisher(for: .jarvisShowInstaller)) { _ in
                showInstaller = true
            }
        }
        .windowStyle(.titleBar)
    }

    @MainActor
    private func checkOllama() async {
        checkingRuntime = true
        defer { checkingRuntime = false }
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            ollamaAvailable = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            ollamaAvailable = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            ollamaAvailable = false
        }
    }
}
