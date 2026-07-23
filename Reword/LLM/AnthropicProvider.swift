import Foundation

/// Talks to Anthropic's native Messages API (api.anthropic.com/v1/messages).
struct AnthropicProvider: LLMProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    private static let apiVersion = "2023-06-01"

    func reformulate(text: String, systemPrompt: String) async throws -> String {
        guard let url = URL(string: normalizedURL()) else {
            throw LLMError.invalidResponse(String(localized: "Invalid base URL:") + " \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "max_tokens": 4096,
            "temperature": 0.3,
            "messages": [
                ["role": "user", "content": text]
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
            let contentBlocks = json["content"] as? [[String: Any]],
            let firstText = contentBlocks.first(where: { $0["type"] as? String == "text" }),
            let text = firstText["text"] as? String
        else {
            throw LLMError.invalidResponse(String(data: data, encoding: .utf8) ?? String(localized: "unreadable response"))
        }

        let result = cleaned(text)
        guard !result.isEmpty else { throw LLMError.emptyResponse }
        return result
    }

    private func normalizedURL() -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTrailingSlash = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return withoutTrailingSlash + "/v1/messages"
    }
}
