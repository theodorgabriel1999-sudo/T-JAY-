import SwiftUI
struct ContentView: View {
    @EnvironmentObject private var vm: InstallerViewModel
    @State private var showPlan = false
    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "square.grid.2x2")
                Label("Components", systemImage: "shippingbox")
                Label("Installer log", systemImage: "doc.text")
            }.listStyle(.sidebar).navigationTitle("JARVIS")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("JARVIS AI WORKSTATION").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
                        Text("Your local AI command center").font(.largeTitle.bold())
                        Text("Prepare your Apple Silicon Mac for local AI and developer workflows.").foregroundStyle(.secondary)
                    }
                    GroupBox("System compatibility") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(vm.hardware.supported ? "Compatible system" : "Unsupported system",
                                  systemImage: vm.hardware.supported ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            Text("\(vm.hardware.chip) · macOS \(vm.hardware.macOS)")
                            Text("\(vm.hardware.memoryGB) GB RAM · \(vm.hardware.freeDiskGB) GB free").foregroundStyle(.secondary)
                            ForEach(vm.hardware.notes, id: \.self) { Text("• " + $0).font(.caption).foregroundStyle(.orange) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installation mode").font(.headline)
                        Picker("Mode", selection: Binding(get: { vm.mode }, set: {
                            vm.mode = $0
                            if $0 == .oneClick { vm.selectRecommended() }
                        })) {
                            Text("Guided").tag(InstallerViewModel.InstallMode.guided)
                            Text("One-click").tag(InstallerViewModel.InstallMode.oneClick)
                        }.pickerStyle(.segmented)
                        Text(vm.mode == .guided ? "Choose individual components." :
                             "Uses the recommended profile; you still review and approve the plan.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Components").font(.headline)
                            Spacer()
                            Button("Recommended profile") { vm.selectRecommended() }.buttonStyle(.link)
                        }
                        ForEach(vm.components) { item in
                            HStack(alignment: .top) {
                                Toggle("", isOn: Binding(
                                    get: { vm.selectedIDs.contains(item.id) },
                                    set: { if $0 { vm.selectedIDs.insert(item.id) } else { vm.selectedIDs.remove(item.id) } }
                                )).labelsHidden()
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(item.name).fontWeight(.semibold); Spacer()
                                        stateView(vm.states[item.id] ?? .idle)
                                    }
                                    Text(item.summary).font(.callout).foregroundStyle(.secondary)
                                    Text("\(item.category) · \(item.license)").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }.padding(.vertical, 5)
                            Divider()
                        }
                    }
                    HStack {
                        Button("Review plan") { showPlan = true }.buttonStyle(.bordered)
                        Spacer()
                        Button {
                            Task { await vm.installSelected() }
                        } label: {
                            if vm.isRunning { ProgressView().controlSize(.small) }
                            else { Label(vm.mode == .oneClick ? "Install recommended" : "Install selected", systemImage: "bolt.fill") }
                        }.buttonStyle(.borderedProminent)
                            .disabled(vm.isRunning || !vm.hardware.supported || vm.selectedComponents.isEmpty)
                    }
                    GroupBox("Activity log") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(vm.logLines.suffix(60).enumerated()), id: \.offset) { _, line in
                                    Text(line).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(height: 150)
                    }
                }.padding(28).frame(maxWidth: 900, alignment: .leading)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .confirmationDialog("Review installation plan", isPresented: $showPlan, titleVisibility: .visible) {
            Button("Start installation") { Task { await vm.installSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The following declared installer commands will run: " +
                 vm.selectedComponents.map(\.name).joined(separator: ", "))
        }
        .tint(.cyan)
    }
    @ViewBuilder private func stateView(_ state: InstallState) -> some View {
        switch state {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .installing: Label("Installing", systemImage: "arrow.down.circle").font(.caption)
        case .succeeded: Label("Installed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
        case .failed(let reason): Text(reason).font(.caption2).foregroundStyle(.red).lineLimit(2)
        }
    }
}
