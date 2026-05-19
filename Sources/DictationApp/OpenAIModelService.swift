import Foundation

struct TranscriptionModel: Equatable {
    let id: String
    let badge: String
}

struct OpenAIModelService {
    enum ServiceError: LocalizedError {
        case invalidResponse
        case serverError(Int, String)
        case noTranscriptionModels

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "OpenAI returned an invalid response."
            case .serverError(let code, let body):
                "OpenAI HTTP \(code): \(body)"
            case .noTranscriptionModels:
                "No transcription models were found for this API key."
            }
        }
    }

    private struct ModelsResponse: Decodable {
        let data: [ModelObject]
    }

    private struct ModelObject: Decodable {
        let id: String
    }

    static let fallbackModels = [
        TranscriptionModel(id: "gpt-4o-mini-transcribe", badge: "быстро"),
        TranscriptionModel(id: "gpt-4o-transcribe", badge: "точнее"),
        TranscriptionModel(id: "gpt-4o-transcribe-diarize", badge: "спикеры"),
        TranscriptionModel(id: "whisper-1", badge: "classic")
    ]

    func fetchTranscriptionModels(apiKey: String) async throws -> [TranscriptionModel] {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw ServiceError.serverError(httpResponse.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        let models = decoded.data
            .map(\.id)
            .filter(Self.isTranscriptionModel)
            .sorted()
            .map { TranscriptionModel(id: $0, badge: Self.badge(for: $0)) }

        guard !models.isEmpty else {
            throw ServiceError.noTranscriptionModels
        }

        return prioritize(models)
    }

    private func prioritize(_ models: [TranscriptionModel]) -> [TranscriptionModel] {
        let preferred = ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "gpt-4o-transcribe-diarize", "whisper-1"]
        return models.sorted { left, right in
            let leftIndex = preferred.firstIndex(of: left.id) ?? Int.max
            let rightIndex = preferred.firstIndex(of: right.id) ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return left.id < right.id
        }
    }

    private static func isTranscriptionModel(_ id: String) -> Bool {
        let normalized = id.lowercased()
        return normalized == "whisper-1"
            || normalized.contains("transcribe")
            || normalized.contains("transcription")
    }

    private static func badge(for id: String) -> String {
        if id.contains("mini") { return "быстро" }
        if id.contains("diarize") { return "спикеры" }
        if id == "whisper-1" { return "classic" }
        return "точнее"
    }
}
