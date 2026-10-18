import Foundation

// Same request as web/server.js; the app can call DeepL directly, the browser couldn't.
enum DeepL {
    // Free-plan keys end in ":fx" and use a different host.
    private static let url = URL(string: (deepLKey.hasSuffix(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com") + "/v2/translate")!

    static func translate(_ text: String, from source: Lang, to target: Lang) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("DeepL-Auth-Key \(deepLKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Always send source_lang explicitly: never let DeepL auto-detect.
        let body = Request(text: [text], sourceLang: source.rawValue, targetLang: target == .EN ? "EN-US" : target.rawValue)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(body)

        let (data, res) = try await URLSession.shared.data(for: req)
        let status = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure(errorDescription: "DeepL \(status): \(String(decoding: data, as: UTF8.self))") }
        return try JSONDecoder().decode(Response.self, from: data).translations[0].text
    }

    private struct Request: Encodable {
        let text: [String]
        let sourceLang: String
        let targetLang: String
    }

    private struct Response: Decodable {
        struct Translation: Decodable { let text: String }
        let translations: [Translation]
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
    }
}
