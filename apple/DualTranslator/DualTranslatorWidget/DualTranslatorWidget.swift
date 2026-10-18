import WidgetKit
import SwiftUI

// Static widget: nothing to refresh, every part is a link into the app (see Translator.open).
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

// Colors from web/style.css.
extension Color {
    init(_ hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    static let text = Color(0xe3e3e3)
    static let muted = Color(0x8e918f)
    static let accent = Color(0xa8c7fa)
    static let chipOn = Color(0x0842a0)
    static let widget = Color(0x2b2b2d)
    static let widgetInner = Color(0x161617)
}

private func link(_ action: String) -> URL { URL(string: "dualtranslator://\(action)")! }

struct DualTranslatorWidgetEntryView: View {
    private let tiles = [("EN", "English"), ("ES", "Spanish"), ("CA", "Catalan")]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Link(destination: link("app")) {
                    HStack(spacing: 10) {
                        Text("文A")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.chipOn, in: .rect(cornerRadius: 7))
                        Text("Enter text")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.muted)
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                Link(destination: link("paste")) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color.text)
                        .frame(width: 44, height: 44)
                }
                .padding(.trailing, 4)
            }
            .frame(height: 52)
            .background(Color.widgetInner, in: .capsule)

            HStack(spacing: 8) {
                ForEach(tiles, id: \.0) { code, name in
                    Link(destination: link(code)) {
                        VStack(spacing: 4) {
                            Text(code)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.accent)
                            Text(name)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.text)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.widgetInner, in: .rect(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(12)
    }
}

struct DualTranslatorWidget: Widget {
    let kind: String = "DualTranslatorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            DualTranslatorWidgetEntryView()
                .containerBackground(Color.widget, for: .widget)
        }
        .configurationDisplayName("Translator")
        .description("Translate between English, Spanish and Catalan.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) {
    DualTranslatorWidget()
} timeline: {
    SimpleEntry(date: .now)
}
