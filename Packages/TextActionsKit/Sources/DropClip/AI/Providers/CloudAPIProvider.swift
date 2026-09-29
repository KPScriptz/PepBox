// CloudAPIProvider.swift
// DropClip
//
// Implements AI processing by querying cloud-based LLM API endpoints (such as OpenAI or Anthropic).
import Foundation
import DropClipCore

@MainActor
public final class CloudAPIProvider: AIProvider {
    public var type: AIProviderType { .cloud }

    public let apiKey: String
    public let model: String
    public let serviceProvider: CloudServiceProvider
    public let customBaseURL: String
    /// Whether a request that finds `model` retired may pick a live model from the provider's
    /// list and try once more. Off for a model the user typed in themselves.
    private let allowsModelRecovery: Bool
    /// Told the model a recovered request moved to, so the next request starts there.
    private let onModelRecovered: (@MainActor (String) -> Void)?

    public init(
        apiKey: String,
        model: String,
        serviceProvider: CloudServiceProvider = .openai,
        customBaseURL: String = "",
        allowsModelRecovery: Bool = false,
        onModelRecovered: (@MainActor (String) -> Void)? = nil
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = trimmedModel.isEmpty ? serviceProvider.primaryModel : trimmedModel
        self.serviceProvider = serviceProvider
        self.customBaseURL = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowsModelRecovery = allowsModelRecovery
        self.onModelRecovered = onModelRecovered
    }

    public func processStream(prompt: String, text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let validated: (prompt: String, text: String)
            do {
                validated = try AIRequestSupport.validateInput(prompt: prompt, text: text)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            guard !apiKey.isEmpty else {
                continuation.finish(throwing: AIError.missingAPIKey)
                return
            }

            let hasInputText = !validated.text.isEmpty
            let systemInstruction = AIRequestSupport.systemPrompt(for: validated.prompt, hasInputText: hasInputText)
            let userContent = AIRequestSupport.userContent(for: validated.text, fallbackPrompt: validated.prompt)
            let firstModel = model

            let streamTask = Task {
                var yieldedAny = false
                do {
                    for try await chunk in self.stream(model: firstModel, systemPrompt: systemInstruction, userContent: userContent) {
                        yieldedAny = true
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    // A model the provider has retired answers before a word is streamed. Then,
                    // and only then, move to a live model and ask once more.
                    guard !yieldedAny, !Task.isCancelled,
                          let replacement = await self.replacementModel(after: error, failedModel: firstModel),
                          !Task.isCancelled else {
                        continuation.finish(throwing: error)
                        return
                    }
                    Log.ai.notice("Cloud model \(firstModel) is unavailable at \(self.serviceProvider.rawValue); retrying with \(replacement)")
                    self.onModelRecovered?(replacement)
                    do {
                        for try await chunk in self.stream(model: replacement, systemPrompt: systemInstruction, userContent: userContent) {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    /// One request to the provider, for `model`.
    private func stream(model: String, systemPrompt: String, userContent: String) -> AsyncThrowingStream<String, Error> {
        switch serviceProvider {
        case .anthropic:
            return streamAnthropic(model: model, systemPrompt: systemPrompt, userContent: userContent)
        case .google:
            return streamGemini(model: model, systemPrompt: systemPrompt, userContent: userContent)
        case .openai, .deepseek, .groq, .openrouter, .custom:
            return streamOpenAICompatible(model: model, systemPrompt: systemPrompt, userContent: userContent, baseURL: effectiveBaseURL)
        }
    }

    // MARK: - Retired models

    /// The model to ask instead when `error` says `failedModel` is gone, or nil to report the
    /// error as it is.
    ///
    /// Only for a built-in provider at its own address (a leftover custom URL is not the
    /// provider's list), and only when the provider's list no longer has the model or the error
    /// says it was retired. A model the provider still lists, with an error that does not say
    /// so, is an access problem (a key without that model, a data policy): the user's choice
    /// stays and the error shows.
    private func replacementModel(after error: Error, failedModel: String) async -> String? {
        guard allowsModelRecovery, serviceProvider != .custom, customBaseURL.isEmpty,
              Self.isModelUnavailable(error) else { return nil }
        let available = (try? await Self.fetchAvailableModels(apiKey: apiKey, provider: serviceProvider)) ?? []
        guard !available.isEmpty else { return nil }
        guard !available.contains(failedModel) || Self.bodyNamesRetirement(error) else { return nil }
        let retired = serviceProvider.retiredModels
        let candidates = available.filter { $0 != failedModel && !retired.contains($0) }
        guard let replacement = serviceProvider.preferredModel(from: candidates), replacement != failedModel else {
            return nil
        }
        return replacement
    }

    /// Whether `error` is the provider saying the model does not exist (any more).
    static func isModelUnavailable(_ error: Error) -> Bool {
        guard let aiError = error as? AIError, case .httpStatus(let status, let body) = aiError else { return false }
        if status == 404 { return true }
        guard status == 400 || status == 410 else { return false }
        let text = (body ?? "").lowercased()
        guard text.contains("model") else { return false }
        let phrases = ["not found", "not exist", "no longer", "decommissioned", "deprecated", "retired", "invalid model", "not a valid model"]
        return phrases.contains { text.contains($0) }
    }

    /// Whether the provider's error names a retirement rather than a missing permission.
    static func bodyNamesRetirement(_ error: Error) -> Bool {
        guard let aiError = error as? AIError, case .httpStatus(_, let body) = aiError else { return false }
        let text = (body ?? "").lowercased()
        let phrases = ["no longer", "decommissioned", "deprecated", "retired", "shut down"]
        return phrases.contains { text.contains($0) }
    }

    public static func resolveBaseURL(provider: CloudServiceProvider, customBaseURL: String = "") -> String {
        let trimmed = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return provider.defaultBaseURL
    }

    public var effectiveBaseURL: String {
        Self.resolveBaseURL(provider: serviceProvider, customBaseURL: customBaseURL)
    }

    private func isOpenAIReasoningModel(_ model: String) -> Bool {
        guard serviceProvider == .openai else { return false }
        let lastComponent = model.split(separator: "/").last.map(String.init) ?? model
        let lower = lastComponent.lowercased()
        return lower.hasPrefix("o1") || lower.hasPrefix("o3")
    }

    // MARK: - OpenAI-compatible chat completions

    private func streamOpenAICompatible(model: String, systemPrompt: String, userContent: String, baseURL: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
                    let endpoint = "\(base)/chat/completions"
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: AIError.invalidURL(endpoint))
                        return
                    }

                    var request = URLRequest(url: url, timeoutInterval: AIRequestSupport.timeoutInterval)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let systemRole = isOpenAIReasoningModel(model) ? "developer" : "system"
                    let body = OpenAIChatRequest(
                        model: model,
                        messages: [
                            .init(role: systemRole, content: systemPrompt),
                            .init(role: "user", content: userContent)
                        ],
                        stream: true
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIError.invalidResponse)
                        return
                    }
                    guard http.statusCode == 200 else {
                        var errorBytes = Data()
                        for try await byte in bytes {
                            errorBytes.append(byte)
                            if errorBytes.count > 1024 { break }
                        }
                        let httpError = AIRequestSupport.httpErrorMessage(status: http.statusCode, data: errorBytes)
                        Log.ai.error("OpenAI-compatible request failed: \(httpError.localizedDescription)")
                        continuation.finish(throwing: httpError)
                        return
                    }

                    struct StreamChunk: Decodable {
                        struct Choice: Decodable {
                            struct Delta: Decodable {
                                let content: String?
                            }
                            let delta: Delta?
                        }
                        let choices: [Choice]?
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let dataStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if dataStr == "[DONE]" { break }
                        guard let chunkData = dataStr.data(using: .utf8) else { continue }
                        if let decoded = try? JSONDecoder().decode(StreamChunk.self, from: chunkData),
                           let content = decoded.choices?.first?.delta?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Anthropic Messages API

    private func streamAnthropic(model: String, systemPrompt: String, userContent: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let base = effectiveBaseURL.hasSuffix("/") ? String(effectiveBaseURL.dropLast()) : effectiveBaseURL
                    let endpoint = "\(base)/messages"
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: AIError.invalidURL(endpoint))
                        return
                    }

                    var request = URLRequest(url: url, timeoutInterval: AIRequestSupport.timeoutInterval)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = AnthropicMessagesRequest(
                        model: model,
                        maxTokens: 4096,
                        system: systemPrompt,
                        messages: [.init(role: "user", content: userContent)],
                        stream: true
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIError.invalidResponse)
                        return
                    }
                    guard http.statusCode == 200 else {
                        var errorBytes = Data()
                        for try await byte in bytes {
                            errorBytes.append(byte)
                            if errorBytes.count > 1024 { break }
                        }
                        let httpError = AIRequestSupport.httpErrorMessage(status: http.statusCode, data: errorBytes)
                        Log.ai.error("Anthropic request failed: \(httpError.localizedDescription)")
                        continuation.finish(throwing: httpError)
                        return
                    }

                    struct AnthropicDeltaEvent: Decodable {
                        struct Delta: Decodable {
                            let type: String?
                            let text: String?
                        }
                        let type: String?
                        let delta: Delta?
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let dataStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if dataStr == "[DONE]" { break }
                        guard let chunkData = dataStr.data(using: .utf8) else { continue }
                        if let decoded = try? JSONDecoder().decode(AnthropicDeltaEvent.self, from: chunkData),
                           let text = decoded.delta?.text, !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Google Gemini API

    private func streamGemini(model: String, systemPrompt: String, userContent: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let base = effectiveBaseURL.hasSuffix("/") ? String(effectiveBaseURL.dropLast()) : effectiveBaseURL
                    let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
                    let endpoint = "\(base)/models/\(encodedModel):streamGenerateContent?alt=sse"
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: AIError.invalidURL(endpoint))
                        return
                    }

                    var request = URLRequest(url: url, timeoutInterval: AIRequestSupport.timeoutInterval)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = GeminiChatRequest(
                        systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                        contents: [.init(parts: [.init(text: userContent)])]
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIError.invalidResponse)
                        return
                    }
                    guard http.statusCode == 200 else {
                        var errorBytes = Data()
                        for try await byte in bytes {
                            errorBytes.append(byte)
                            if errorBytes.count > 1024 { break }
                        }
                        let httpError = AIRequestSupport.httpErrorMessage(status: http.statusCode, data: errorBytes)
                        Log.ai.error("Gemini request failed: \(httpError.localizedDescription)")
                        continuation.finish(throwing: httpError)
                        return
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let dataStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let chunkData = dataStr.data(using: .utf8) else { continue }
                        // Gemini 3 can split a chunk over several parts, and a thinking model's
                        // thought summaries are parts of their own: the answer is every other part.
                        if let decoded = try? JSONDecoder().decode(GeminiChatResponse.self, from: chunkData),
                           let parts = decoded.candidates?.first?.content?.parts {
                            let text = parts
                                .filter { $0.thought != true }
                                .compactMap(\.text)
                                .joined()
                            if !text.isEmpty {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public static func fetchAvailableModels(apiKey: String, provider: CloudServiceProvider, customBaseURL: String = "") async throws -> [String] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw AIError.missingAPIKey
        }

        let baseURL = resolveBaseURL(provider: provider, customBaseURL: customBaseURL)
        switch provider {
        case .anthropic:
            return try await fetchAnthropicModels(apiKey: trimmedKey, baseURL: baseURL)
        case .google:
            return try await fetchGeminiModels(apiKey: trimmedKey, baseURL: baseURL)
        case .openai, .deepseek, .groq, .openrouter, .custom:
            return try await fetchOpenAICompatibleModels(apiKey: trimmedKey, baseURL: baseURL, provider: provider)
        }
    }

    private static func fetchOpenAICompatibleModels(apiKey: String, baseURL: String, provider: CloudServiceProvider) async throws -> [String] {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let endpoint = "\(base)/models"
        guard let url = URL(string: endpoint) else {
            throw AIError.invalidURL(endpoint)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.invalidResponse
        }

        struct ModelListResponse: Decodable {
            struct ModelItem: Decodable {
                let id: String
            }
            let data: [ModelItem]?
        }

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        let modelIds = (decoded.data ?? []).map { $0.id }
        
        if provider == .openai {
            // Chat models only: not the audio, realtime, speech, image, search or embedding ones.
            let excluded = ["audio", "realtime", "transcribe", "tts", "image", "search", "embedding", "moderation", "whisper", "dall-e"]
            let filtered = modelIds.filter { id in
                let l = id.lowercased()
                guard !excluded.contains(where: { l.contains($0) }) else { return false }
                return l.contains("gpt") || l.contains("o1") || l.contains("o3") || l.contains("chat")
            }.sorted()
            return filtered.isEmpty ? modelIds.sorted() : filtered
        } else {
            return modelIds.sorted()
        }
    }

    private static func fetchAnthropicModels(apiKey: String, baseURL: String) async throws -> [String] {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        // The whole list in one page (the default page is 20), newest first as the API sends it.
        let endpoint = "\(base)/models?limit=1000"
        guard let url = URL(string: endpoint) else {
            throw AIError.invalidURL(endpoint)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.invalidResponse
        }

        struct AnthropicModelListResponse: Decodable {
            struct ModelItem: Decodable {
                let id: String
            }
            let data: [ModelItem]?
        }

        let decoded = try JSONDecoder().decode(AnthropicModelListResponse.self, from: data)
        return (decoded.data ?? []).map { $0.id }
    }

    private static func fetchGeminiModels(apiKey: String, baseURL: String) async throws -> [String] {
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        // The whole list in one page (the default page is 50).
        let endpoint = "\(base)/models?pageSize=1000"
        guard let url = URL(string: endpoint) else {
            throw AIError.invalidURL(endpoint)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.invalidResponse
        }

        struct GeminiModelListResponse: Decodable {
            struct ModelItem: Decodable {
                let name: String
                let supportedGenerationMethods: [String]?
            }
            let models: [ModelItem]?
        }

        // Text models that answer `generateContent`: not the embedding, speech, image, live,
        // transcription, computer-use, robotics or translation ones.
        let excluded = ["embedding", "tts", "image", "live", "audio", "transcribe", "computer-use", "robotics", "translate"]
        let decoded = try JSONDecoder().decode(GeminiModelListResponse.self, from: data)
        let ids = (decoded.models ?? []).compactMap { item -> String? in
            let id = item.name.hasPrefix("models/") ? String(item.name.dropFirst("models/".count)) : item.name
            guard id.hasPrefix("gemini") else { return nil }
            if let methods = item.supportedGenerationMethods, !methods.contains("generateContent") { return nil }
            guard !excluded.contains(where: { id.contains($0) }) else { return nil }
            return id
        }.sorted()

        return ids.isEmpty ? CloudServiceProvider.google.defaultModels : ids
    }
}
