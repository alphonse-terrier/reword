import Foundation

/// A user-defined external command that receives the selected text on stdin and returns the
/// rewritten text on stdout — lets Reword drive any LLM CLI (Ollama, Gemini CLI, `llm`, custom
/// scripts) without a dedicated provider implementation.
///
/// `{system}` and `{model}` in `arguments` are substituted with the resolved system prompt and
/// model name before launch; the executable is resolved via `ShellEnvironment` if not absolute.
struct CommandProvider: LLMProvider {
    let executable: String
    let arguments: [String]
    let model: String

    func reformulate(text: String, systemPrompt: String) async throws -> String {
        let trimmedExecutable = executable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExecutable.isEmpty else {
            throw LLMError.invalidResponse(String(localized: "No command configured. Set one in Settings → Provider."))
        }

        do {
            let executablePath = try ShellEnvironment.resolvePath(for: trimmedExecutable)
            let resolvedArguments = arguments.map { arg in
                arg.replacingOccurrences(of: "{system}", with: systemPrompt)
                    .replacingOccurrences(of: "{model}", with: model)
            }

            let output = try await ProcessRunner.run(
                executablePath: executablePath,
                arguments: resolvedArguments,
                environment: ShellEnvironment.loginEnvironment(),
                stdin: text
            )
            let result = cleaned(output)
            guard !result.isEmpty else { throw LLMError.emptyResponse }
            return result
        } catch let error as LLMError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LLMError.invalidResponse(error.localizedDescription)
        }
    }
}
