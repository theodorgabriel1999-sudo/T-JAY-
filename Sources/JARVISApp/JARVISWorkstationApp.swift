import SwiftUI

@main
struct JARVISWorkstationApp: App {
    @StateObject private var installer = InstallerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(installer)
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowStyle(.titleBar)
    }
}
