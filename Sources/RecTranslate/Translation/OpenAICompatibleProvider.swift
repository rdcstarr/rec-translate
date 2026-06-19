import Foundation

/// Translates via an OpenAI-compatible Chat Completions API (OpenAI, DeepSeek, …). These services
/// have no dedicated text-translation endpoint, so a terse system prompt steers a chat model to
/// return only the translated text (preserving formatting and the source's shape). One provider
/// serves every compatible backend — only the endpoint, key, and model differ.
struct OpenAICompatibleProvider: TranslationProvider {
    let endpoint: URL
    let apiKey: String
    let model: String

    func translate(text: String, source: String, target: String) async throws -> ProviderResult {
        let targetName = Languages.name(for: target)
        let sourceInstruction = (source == Language.auto.code)
            ? "Detect the source language and translate the text into \(targetName)."
            : "Translate the text from \(Languages.name(for: source)) into \(targetName)."

        let system = """
        You are a professional translation engine. \(sourceInstruction)
        Return ONLY the translated text — no quotes, no notes, no explanations. Preserve the original \
        line breaks, spacing, capitalization style, punctuation, and any markdown/formatting. Keep \
        code, URLs, @handles, emoji, and placeholders unchanged. If the text is already in the target \
        language, return it unchanged.
        """

        let payload = ChatRequest(
            model: model,
            temperature: 0,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: text),
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.network("No HTTP response.")
        }

        switch http.statusCode {
        case 200:
            let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data)
            let content = decoded?.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let content, !content.isEmpty else { throw TranslationError.decoding }
            // Compatible APIs don't report a detected language; the on-device detector covers the label.
            return ProviderResult(translation: content, detected: nil)
        case 401:
            throw TranslationError.unauthorized
        case 429:
            throw TranslationError.upstreamFailure("Rate limit or quota exceeded — check your plan and billing.")
        default:
            let apiError = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw TranslationError.unexpectedStatus(http.statusCode, apiError?.error.message)
        }
    }

    // MARK: - Wire formats (OpenAI-compatible)

    private struct ChatRequest: Encodable {
        let model: String
        let temperature: Double
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String? }
    }

    private struct ErrorResponse: Decodable {
        let error: APIError
        struct APIError: Decodable { let message: String? }
    }
}

/// Endpoints for the OpenAI-compatible backends the app supports.
enum ChatCompletionsEndpoint {
    static let openAI = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let deepSeek = URL(string: "https://api.deepseek.com/v1/chat/completions")!
}
