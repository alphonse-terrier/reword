import Foundation

/// Talks to any endpoint implementing the OpenAI `/chat/completions` API shape:
/// OpenAI itself, Ollama's OpenAI-compatible mode, LM Studio, vLLM, OpenRouter, etc.
struct OpenAICompatibleProvider: LLMProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    func reformulate(text: String, systemPrompt: String) async throws -> String {
        guard let url = URL(string: normalizedURL()) else {
            throw LLMError.invalidResponse(String(localized: "Invalid base URL:") + " \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "stream": false,
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
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse(String(data: data, encoding: .utf8) ?? String(localized: "unreadable response"))
        }

        let result = cleaned(content)
        guard !result.isEmpty else { throw LLMError.emptyResponse }
        return result
    }

    private func normalizedURL() -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTrailingSlash = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return withoutTrailingSlash + "/chat/completions"
    }
}
