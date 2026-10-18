import SwiftUI

enum Lang: String, CaseIterable, Identifiable {
    case EN, ES, CA

    var id: Self { self }
    var name: String {
        switch self {
        case .EN: "English"
        case .ES: "Spanish"
        case .CA: "Catalan"
        }
    }
    var others: [Lang] { Self.allCases.filter { $0 != self } }
}

// Same behavior as web/app.js.
@Observable
final class Translator {
    private(set) var source = Lang(rawValue: UserDefaults.standard.string(forKey: "source") ?? "") ?? .EN
    private(set) var input = ""
    private(set) var stale = false
    private(set) var error: String?
    private var texts: [Lang: String] = [:] // all three languages once a translation has come back
    private var task: Task<Void, Never>?

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    func output(_ lang: Lang) -> String { trimmed.isEmpty ? "" : texts[lang] ?? "" }

    func edit(_ text: String) {
        input = text
        stale = false
        error = nil
        task?.cancel()
        if trimmed.isEmpty {
            texts = [:]
            return
        }
        task = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled { await translate() }
        }
    }

    func setSource(_ lang: Lang) {
        guard lang != source else { return }
        let text = trimmed
        let translated = !text.isEmpty && texts[source] == text
        source = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "source")
        task?.cancel()
        stale = false
        error = nil
        if translated {
            // Already have all three: just show this language's text as the input, no API call.
            input = texts[lang] ?? ""
        } else {
            texts = [:]
            if !text.isEmpty { task = Task { await translate() } }
        }
    }

    // Widget links: dualtranslator://app opens with the last-used language,
    // dualtranslator://EN (ES, CA) with that language, dualtranslator://paste with the clipboard.
    func open(_ url: URL) {
        guard url.scheme == "dualtranslator", let action = url.host() else { return }
        input = ""
        texts = [:]
        if let lang = Lang(rawValue: action) { setSource(lang) }
        edit(action == "paste" ? UIPasteboard.general.string ?? "" : "")
    }

    private func translate() async {
        let text = trimmed, src = source, targets = src.others
        stale = true
        do {
            async let a = DeepL.translate(text, from: src, to: targets[0])
            async let b = DeepL.translate(text, from: src, to: targets[1])
            let (ra, rb) = try await (a, b)
            guard !Task.isCancelled else { return }
            texts = [src: text, targets[0]: ra, targets[1]: rb]
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        stale = false
    }
}
