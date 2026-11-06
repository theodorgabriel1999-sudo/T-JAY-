import SwiftUI
import Foundation

struct WorkstationView: View {
    @StateObject private var assistant = LocalAssistant()
    @State private var prompt = ""

    var body: some View {
        NavigationSplitView {
            List {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                Label("Local models", systemImage: "cube")
                Section("Runtime") {
                    Label(assistant.isConnected ? "Ollama connected" : "Ollama unavailable",
                          systemImage: assistant.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(assistant.isConnected ? .green : .orange)
                }
            }
            .navigationTitle("JARVIS")
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("JARVIS WORKSTATION").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
                        Text("Local AI assistant").font(.largeTitle.bold())
                    }
                    Spacer()
                    Button("Refresh models") { Task { await assistant.refreshModels() } }
                    Button("Installer") { assistant.showInstallerRequested = true }
                        .buttonStyle(.bordered)
                }
                .padding()

                HStack {
                    Text("Model")
                    Picker("Model", selection: $assistant.selectedModel) {
                        if assistant.models.isEmpty {
                            Text("No models found").tag("")
                        }
                        ForEach(assistant.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .frame(maxWidth: 260)
                    Spacer()
                    Text(assistant.status).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider().padding(.top, 12)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if assistant.messages.isEmpty {
                            ContentUnavailableView("Ready when you are",
                                systemImage: "sparkles",
                                description: Text("Choose an installed Ollama model and ask JARVIS a question. Your conversation runs through your local Ollama service."))
                                .padding(.top, 70)
                        }
                        ForEach(assistant.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.role == "user" ? "YOU" : "JARVIS")
                                    .font(.caption.bold()).foregroundStyle(message.role == "user" ? .cyan : .secondary)
                                Text(message.content).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(message.role == "user" ? Color.cyan.opacity(0.08) : Color.secondary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }

                Divider()
                HStack(alignment: .bottom) {
                    TextField("Message JARVIS…", text: $prompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .onSubmit { send() }
                    Button {
                        send()
                    } label: {
                        if assistant.isSending { ProgressView() }
                        else { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    }
                    .disabled(assistant.isSending || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.selectedModel.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .task { await assistant.refreshModels() }
        .onChange(of: assistant.showInstallerRequested) { _, requested in
            if requested { NotificationCenter.default.post(name: .jarvisShowInstaller, object: nil) }
        }
    }

    private func send() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prompt = ""
        Task { await assistant.send(text) }
    }
}

extension Notification.Name {
    static let jarvisShowInstaller = Notification.Name("JARVISShowInstaller")
}

@MainActor
final class LocalAssistant: ObservableObject {
    @Published var models: [String] = []
    @Published var selectedModel = ""
    @Published var messages: [LocalChatMessage] = []
    @Published var isConnected = false
    @Published var isSending = false
    @Published var status = "Checking local Ollama…"
    @Published var showInstallerRequested = false

    private let baseURL = URL(string: "http://localhost:11434")!

    func refreshModels() async {
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let result = try JSONDecoder().decode(OllamaTags.self, from: data)
            models = result.models.map(\.name).sorted()
            if !models.contains(selectedModel) { selectedModel = models.first ?? "" }
            isConnected = true
            status = models.isEmpty ? "Ollama connected · no models installed" : "\(models.count) local model(s) ready"
        } catch {
            isConnected = false
            status = "Ollama is not responding at localhost:11434"
            models = []
            selectedModel = ""
        }
    }

    func send(_ text: String) async {
        guard !selectedModel.isEmpty, !isSending else { return }
        messages.append(LocalChatMessage(role: "user", content: text))
        isSending = true
        defer { isSending = false }
        do {
            let payload = OllamaChatRequest(model: selectedModel,
                messages: messages.map { OllamaChatTurn(role: $0.role, content: $0.content) },
                stream: false)
            var request = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            request.timeoutInterval = 300
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            messages.append(LocalChatMessage(role: "assistant", content: result.message.content))
            status = "Connected · \(selectedModel)"
        } catch {
            messages.append(LocalChatMessage(role: "assistant",
                content: "I couldn't reach the local model. Check that Ollama is running and try again. Details: \(error.localizedDescription)"))
            status = "Chat request failed"
        }
    }
}

struct LocalChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}
private struct OllamaTags: Decodable { let models: [OllamaModel] }
private struct OllamaModel: Decodable { let name: String }
private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaChatTurn]
    let stream: Bool
}
private struct OllamaChatTurn: Codable { let role: String; let content: String }
private struct OllamaChatResponse: Decodable { let message: OllamaChatTurn }
