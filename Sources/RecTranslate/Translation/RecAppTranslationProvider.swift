import Foundation

/// Calls rec-app's translate API:
///
///     POST {baseURL}/api/translate/{source}/{target}
///     Authorization: Bearer <key with the "translate" ability>
///     Content-Type: application/json
///     { "text": "<text>" }
///
/// Success 200 → `{ source, target, text, translation }`. The provider returns only the
/// `translation`; on-device detection (handled by `TranslationService`) supplies the source.
struct RecAppTranslationProvider: TranslationProvider {
    let baseURL: URL
    let apiKey: String

    func translate(text: String, source: String, target: String) async throws -> String {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("translate")
            .appendingPathComponent(source)
            .appendingPathComponent(target)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(["text": text])
        request.timeoutInterval = 30

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
            guard let decoded = try? JSONDecoder().decode(RecAppTranslateResponse.self, from: data) else {
                throw TranslationError.decoding
            }
            return decoded.translation
        case 401:
            throw TranslationError.unauthorized
        case 403:
            throw TranslationError.forbidden
        case 422:
            throw TranslationError.invalidInput(
                RecAppErrorResponse.message(from: data) ?? "Invalid language or text."
            )
        case 502:
            throw TranslationError.upstreamFailure(RecAppErrorResponse.message(from: data))
        default:
            throw TranslationError.unexpectedStatus(http.statusCode, RecAppErrorResponse.message(from: data))
        }
    }
}
