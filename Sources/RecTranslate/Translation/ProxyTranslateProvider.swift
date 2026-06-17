import Foundation

/// Calls the translate endpoint hosted directly on proxy123.click:
///
///     POST {baseURL}/translate/{source}/{target}
///     Authorization: Bearer <proxy123 API_BEARER_TOKEN>
///     Content-Type: application/json
///     { "text": "<text>" }
///
/// The server translates through its own rotating proxy pool and supports `source = auto`
/// (Google detects the language and returns it as `detected`). Success 200 →
/// `{ success, source, target, text, translation, detected }`; errors → `{ success:false, error }`.
struct ProxyTranslateProvider: TranslationProvider {
    let baseURL: URL
    let token: String

    func translate(text: String, source: String, target: String) async throws -> ProviderResult {
        let url = baseURL
            .appendingPathComponent("translate")
            .appendingPathComponent(source)
            .appendingPathComponent(target)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(["text": text])
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

        let decoded = try? JSONDecoder().decode(ProxyTranslateResponse.self, from: data)

        switch http.statusCode {
        case 200:
            guard let decoded, decoded.success, let translation = decoded.translation else {
                throw TranslationError.decoding
            }
            return ProviderResult(translation: translation, detected: decoded.detected)
        case 401:
            throw TranslationError.unauthorized
        case 403:
            throw TranslationError.forbidden
        case 422:
            throw TranslationError.invalidInput(decoded?.error ?? "Invalid language or text.")
        case 502:
            throw TranslationError.upstreamFailure(decoded?.error)
        default:
            throw TranslationError.unexpectedStatus(http.statusCode, decoded?.error)
        }
    }
}
