import XCTest
@testable import Reword

final class LLMProviderFactoryTests: XCTestCase {
    func testOpenAICompatible() {
        let provider = LLMProviderFactory.make(
            providerType: .openAICompatible, baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini",
            apiKey: "key", commandExecutable: "", commandArgumentsLine: ""
        )
        XCTAssertTrue(provider is OpenAICompatibleProvider)
    }

    func testAnthropic() {
        let provider = LLMProviderFactory.make(
            providerType: .anthropic, baseURL: "https://api.anthropic.com", model: "claude-sonnet-5",
            apiKey: "key", commandExecutable: "", commandArgumentsLine: ""
        )
        XCTAssertTrue(provider is AnthropicProvider)
    }

    func testOllama() {
        let provider = LLMProviderFactory.make(
            providerType: .ollama, baseURL: "http://localhost:11434", model: "llama3",
            apiKey: "", commandExecutable: "", commandArgumentsLine: ""
        )
        XCTAssertTrue(provider is OllamaProvider)
    }

    func testClaudeCLIFallsBackToDefaultModelWhenEmpty() {
        let provider = LLMProviderFactory.make(
            providerType: .claudeCLI, baseURL: "", model: "",
            apiKey: "", commandExecutable: "", commandArgumentsLine: ""
        )
        guard let claudeProvider = provider as? ClaudeCLIProvider else {
            return XCTFail("Expected ClaudeCLIProvider")
        }
        XCTAssertEqual(claudeProvider.model, ProviderType.claudeCLI.defaultModel)
    }

    func testCustomCommandTokenizesArguments() {
        let provider = LLMProviderFactory.make(
            providerType: .customCommand,
            baseURL: "",
            model: "llama3",
            apiKey: "",
            commandExecutable: "ollama",
            commandArgumentsLine: "run {model}"
        )
        guard let commandProvider = provider as? CommandProvider else {
            return XCTFail("Expected CommandProvider")
        }
        XCTAssertEqual(commandProvider.executable, "ollama")
        XCTAssertEqual(commandProvider.arguments, ["run", "{model}"])
    }
}
