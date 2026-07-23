import Foundation

/// Talks to Ollama's native API (`/api/chat`), as opposed to its OpenAI-compatible shim.
/// Useful when the user wants a dedicated "Ollama" entry with a plain host (no `/v1` suffix).
struct OllamaProvider: LLMProvider {
    let host: String
    let model: String

    func reformulate(text: String, systemPrompt: String) async throws -> String {
        guard let url = URL(string: normalizedURL()) else {
            throw LLMError.invalidResponse(String(localized: "Invalid host:") + " \(host)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? String(localized: "<binary>")
            throw LLMError.httpError(http.statusCode, bodyText)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse(String(data: data, encoding: .utf8) ?? String(localized: "unreadable response"))
        }

        let result = cleaned(content)
        guard !result.isEmpty else { throw LLMError.emptyResponse }
        return result
    }

    private func normalizedURL() -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTrailingSlash = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return withoutTrailingSlash + "/api/chat"
    }
}
