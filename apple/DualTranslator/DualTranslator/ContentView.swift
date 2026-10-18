import SwiftUI

// Colors from web/style.css.
extension Color {
    init(_ hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    static let bg = Color(0x131314)
    static let text = Color(0xe3e3e3)
    static let muted = Color(0x8e918f)
    static let accent = Color(0xa8c7fa)
    static let divider = Color(0x0b4f7c)
    static let bar = Color(0x1f1f20)
    static let chip = Color(0x111112)
    static let chipOn = Color(0x0842a0)
    static let pasteBg = Color(0x004a77)
}

// Long text gets smaller, like Google Translate.
private func fontSize(_ s: String) -> CGFloat { s.count > 120 ? 19 : s.count > 40 ? 24 : 30 }

struct ContentView: View {
    @State private var model = Translator()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sourceBlock
                    Rectangle()
                        .fill(Color.divider)
                        .frame(height: 2)
                        .containerRelativeFrame(.horizontal) { w, _ in (w - 48) / 2 }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    ForEach(Array(model.source.others.enumerated()), id: \.element) { i, lang in
                        outputBlock(lang).padding(.top, i == 0 ? 0 : 16)
                    }
                }
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24))
            }
            // Any swipe closes the keyboard; bounce so it works even when the text fits on screen.
            .scrollDismissesKeyboard(.immediately)
            .scrollBounceBehavior(.always)
            langBar
        }
        .background(Color.bg)
        .onAppear { focused = true }
        .onOpenURL { url in
            model.open(url)
            focused = true
        }
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            label(model.source.name, color: .text)
            HStack(alignment: .top, spacing: 4) {
                TextField("", text: Binding(get: { model.input }, set: { model.edit($0) }),
                          prompt: Text("Enter text").foregroundStyle(Color.muted), axis: .vertical)
                    .font(.system(size: fontSize(model.input)))
                    .foregroundStyle(Color.text)
                    .tint(Color.accent)
                    .autocorrectionDisabled()
                    .focused($focused)
                if !model.input.isEmpty {
                    Button {
                        model.edit("")
                        focused = true
                    } label: {
                        icon("xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.muted)
                    .padding(.top, -6)
                    .padding(.trailing, -12)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            if model.input.isEmpty {
                // System paste button: reads the clipboard without the "Allow Paste" prompt.
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in
                        model.edit(strings.first ?? "")
                        focused = true
                    }
                }
                .tint(Color.pasteBg)
                .buttonBorderShape(.capsule)
                .padding(.top, 8)
                .padding(.bottom, 16)
            } else {
                CopyButton(text: model.input, color: .muted)
            }
        }
        .padding(.top, 8)
    }

    private func outputBlock(_ lang: Lang) -> some View {
        let value = model.output(lang)
        return VStack(alignment: .leading, spacing: 0) {
            label(lang.name, color: .accent)
            Group {
                if let error = model.error {
                    Text("Couldn't translate. \(error)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.muted)
                } else {
                    Text(value)
                        .font(.system(size: fontSize(value)))
                        .foregroundStyle(Color.accent)
                        .opacity(model.stale ? 0.5 : 1)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
            .padding(.top, 16)
            .padding(.bottom, 8)
            CopyButton(text: value, color: .accent)
        }
        .padding(.top, 8)
    }

    private var langBar: some View {
        HStack(spacing: 8) {
            ForEach(Lang.allCases) { lang in
                let on = lang == model.source
                Button {
                    model.setSource(lang)
                } label: {
                    Text(lang.name)
                        .font(.system(size: 15))
                        .foregroundStyle(on ? Color.white : Color.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? Color.chipOn : Color.chip, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bar)
    }

    private func label(_ s: String, color: Color) -> some View {
        Text(s)
            .font(.system(size: 15))
            .foregroundStyle(color)
            .frame(minHeight: 20)
    }
}

private func icon(_ name: String) -> some View {
    Image(systemName: name)
        .font(.system(size: 20, weight: .light))
        .frame(width: 44, height: 44)
        .contentShape(.rect)
}

private struct CopyButton: View {
    let text: String
    let color: Color
    @State private var copied = false

    var body: some View {
        Button {
            guard !text.isEmpty else { return }
            UIPasteboard.general.string = text
            copied = true
        } label: {
            icon(copied ? "checkmark" : "square.on.square")
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, -10)
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
