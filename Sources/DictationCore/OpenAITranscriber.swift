import Foundation

struct OpenAITranscriber {
    enum TranscriberError: LocalizedError {
        case invalidResponse
        case serverError(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "OpenAI returned an invalid response."
            case .serverError(let code, let body):
                "OpenAI HTTP \(code): \(body)"
            }
        }
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }

    func transcribe(fileURL: URL, apiKey: String, model: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try multipartBody(
            boundary: boundary,
            fields: [
                "model": model,
                "response_format": "json"
            ],
            fileField: "file",
            fileURL: fileURL,
            mimeType: "audio/mp4"
        )

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriberError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw TranscriberError.serverError(httpResponse.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        fileField: String,
        fileURL: URL,
        mimeType: String
    ) throws -> Data {
        var data = Data()

        for (key, value) in fields {
            data.appendUTF8("--\(boundary)\r\n")
            data.appendUTF8("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            data.appendUTF8("\(value)\r\n")
        }

        let fileData = try Data(contentsOf: fileURL)
        data.appendUTF8("--\(boundary)\r\n")
        data.appendUTF8("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        data.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendUTF8("\r\n")
        data.appendUTF8("--\(boundary)--\r\n")

        return data
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(Data(value.utf8))
    }
}
