import WidgetKit
import SwiftUI

enum WidgetStyle: String {
    case klasikTuruncu
    case miniSunset
    case glassmorphism
    case neonGlow
    case timeline
    case cosmic
    case zen
    case origami
}

struct WidgetFamilies {
    static let all: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .accessoryInline,
        .accessoryCircular,
        .accessoryRectangular
    ]
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct WidgetData {
    let nextPrayer: String
    let nextTime: String
    let remaining: String
    let remainingShort: String
    let currentPrayer: String
    let currentTime: String
    let dateText: String
    let dateShort: String
    let hijriDate: String
    let location: String
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String
    let dailyQuote: String
    let dailyQuoteSource: String
    let esmaName: String
    let esmaMeaning: String
    let specialDayName: String
    let specialDayMessage: String
    let hasSpecialDay: Bool
    let labelTimeRemaining: String
    let labelTimeTo: String
    let labelCurrentTime: String
    let labelNowAt: String
    let labelNowInTime: String
    let labelImsak: String
    let labelGunes: String
    let labelOgle: String
    let labelIkindi: String
    let labelAksam: String
    let labelYatsi: String
    let backgroundKey: String
    let textColorHex: String
    let opacity: Double
}

struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: WidgetData.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), data: WidgetData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry(date: Date(), data: WidgetData.load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct WidgetRootView: View {
    let entry: WidgetEntry
    let style: WidgetStyle
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            if isAccessoryFamily {
                AccessoryWidgetBackground()
            } else {
                backgroundView
            }

            contentView
                .padding(isAccessoryFamily ? 6 : 12)
        }
        .foregroundColor(textColor)
    }

    private var contentView: some View {
        switch family {
        case .accessoryInline:
            return AnyView(inlineView)
        case .accessoryCircular:
            return AnyView(circularView)
        case .accessoryRectangular:
            return AnyView(rectangularView)
        case .systemSmall:
            return AnyView(smallView)
        case .systemMedium:
            return AnyView(mediumView)
        default:
            return AnyView(largeView)
        }
    }

    private var inlineView: some View {
        Text("\(entry.data.nextPrayer) \(entry.data.remainingShort)")
            .font(.caption)
    }

    private var circularView: some View {
        VStack(spacing: 2) {
            Text(entry.data.nextPrayer)
                .font(.caption2)
                .minimumScaleFactor(0.6)
            Text(entry.data.remainingShort)
                .font(.caption2)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.data.labelTimeRemaining)
                .font(.caption2)
                .foregroundStyle(textColor.opacity(0.8))
            Text("\(entry.data.nextPrayer) \(entry.data.labelTimeTo) \(entry.data.remainingShort)")
                .font(.caption)
                .lineLimit(2)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.data.labelTimeRemaining)
                .font(.caption2)
                .foregroundStyle(textColor.opacity(0.8))
            Text(entry.data.nextPrayer)
                .font(.headline)
            Text(entry.data.remaining)
                .font(.subheadline)
            Spacer()
            Text(entry.data.dateShort)
                .font(.caption2)
                .foregroundStyle(textColor.opacity(0.7))
        }
    }

    private var mediumView: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.data.labelTimeRemaining)
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.8))
                Text(entry.data.nextPrayer)
                    .font(.title3)
                Text(entry.data.remaining)
                    .font(.subheadline)
                Text(entry.data.location)
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.7))
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 4) {
                timeRow(label: entry.data.labelImsak, time: entry.data.imsak)
                timeRow(label: entry.data.labelGunes, time: entry.data.gunes)
                timeRow(label: entry.data.labelOgle, time: entry.data.ogle)
                timeRow(label: entry.data.labelIkindi, time: entry.data.ikindi)
                timeRow(label: entry.data.labelAksam, time: entry.data.aksam)
                timeRow(label: entry.data.labelYatsi, time: entry.data.yatsi)
            }
            .font(.caption2)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.data.labelTimeRemaining)
                        .font(.caption2)
                        .foregroundStyle(textColor.opacity(0.8))
                    Text(entry.data.nextPrayer)
                        .font(.title2)
                    Text(entry.data.remaining)
                        .font(.title3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.data.dateText)
                        .font(.caption)
                    Text(entry.data.hijriDate)
                        .font(.caption2)
                        .foregroundStyle(textColor.opacity(0.7))
                }
            }

            Divider().overlay(textColor.opacity(0.4))

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    timeRow(label: entry.data.labelImsak, time: entry.data.imsak)
                    timeRow(label: entry.data.labelGunes, time: entry.data.gunes)
                    timeRow(label: entry.data.labelOgle, time: entry.data.ogle)
                }
                VStack(alignment: .leading, spacing: 4) {
                    timeRow(label: entry.data.labelIkindi, time: entry.data.ikindi)
                    timeRow(label: entry.data.labelAksam, time: entry.data.aksam)
                    timeRow(label: entry.data.labelYatsi, time: entry.data.yatsi)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    if entry.data.hasSpecialDay {
                        Text(entry.data.specialDayName)
                            .font(.caption)
                        Text(entry.data.specialDayMessage)
                            .font(.caption2)
                            .lineLimit(3)
                            .foregroundStyle(textColor.opacity(0.8))
                    } else {
                        Text(entry.data.esmaName)
                            .font(.caption)
                        Text(entry.data.esmaMeaning)
                            .font(.caption2)
                            .lineLimit(3)
                            .foregroundStyle(textColor.opacity(0.8))
                    }
                }
                .frame(maxWidth: 140, alignment: .leading)
            }

            Text(entry.data.dailyQuote)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(textColor.opacity(0.8))
        }
    }

    private func timeRow(label: String, time: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 56, alignment: .leading)
            Text(time)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var isAccessoryFamily: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            return true
        default:
            return false
        }
    }

    private var textColor: Color {
        if let color = Color(hex: entry.data.textColorHex) {
            return color
        }
        return theme.text
    }

    private var backgroundView: some View {
        ZStack {
            theme.background
                .opacity(entry.data.opacity)
            if style == .glassmorphism {
                Color.white.opacity(0.12)
            }
            if style == .neonGlow {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.accent, lineWidth: 2)
                    .blur(radius: 4)
            }
        }
        .cornerRadius(16)
    }

    private var theme: WidgetTheme {
        switch style {
        case .klasikTuruncu:
            return WidgetTheme(background: LinearGradient(colors: [Color.orange, Color(red: 0.85, green: 0.35, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), text: .white, accent: .white)
        case .miniSunset:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.96, green: 0.6, blue: 0.35), Color(red: 0.96, green: 0.32, blue: 0.32)], startPoint: .top, endPoint: .bottom), text: .white, accent: .yellow)
        case .glassmorphism:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.14, green: 0.18, blue: 0.25), Color(red: 0.08, green: 0.12, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), text: .white, accent: .white)
        case .neonGlow:
            return WidgetTheme(background: LinearGradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), text: .white, accent: Color(red: 0.1, green: 1.0, blue: 0.9))
        case .timeline:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.35), Color(red: 0.08, green: 0.12, blue: 0.2)], startPoint: .top, endPoint: .bottom), text: .white, accent: .cyan)
        case .cosmic:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.06, green: 0.05, blue: 0.14), Color(red: 0.15, green: 0.08, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), text: .white, accent: Color(red: 0.7, green: 0.4, blue: 1.0))
        case .zen:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.75, green: 0.82, blue: 0.78), Color(red: 0.6, green: 0.72, blue: 0.66)], startPoint: .top, endPoint: .bottom), text: Color(red: 0.1, green: 0.18, blue: 0.15), accent: Color(red: 0.2, green: 0.35, blue: 0.3))
        case .origami:
            return WidgetTheme(background: LinearGradient(colors: [Color(red: 0.9, green: 0.85, blue: 0.8), Color(red: 0.95, green: 0.75, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), text: Color(red: 0.25, green: 0.15, blue: 0.1), accent: Color(red: 0.85, green: 0.45, blue: 0.35))
        }
    }
}

struct WidgetTheme {
    let background: LinearGradient
    let text: Color
    let accent: Color
}

extension WidgetData {
    static let placeholder = WidgetData(
        nextPrayer: "Ogle",
        nextTime: "12:30",
        remaining: "2s 30dk kaldI",
        remainingShort: "2s 30dk",
        currentPrayer: "Gunes",
        currentTime: "07:00",
        dateText: "07 Subat 2026",
        dateShort: "07 Sub 2026",
        hijriDate: "18 Receb 1447",
        location: "Istanbul / Kadikoy",
        imsak: "05:30",
        gunes: "07:00",
        ogle: "12:30",
        ikindi: "15:30",
        aksam: "18:00",
        yatsi: "19:30",
        dailyQuote: "Ameller niyetlere goredir.",
        dailyQuoteSource: "Buhari",
        esmaName: "Er-Rahman",
        esmaMeaning: "Merhameti bol",
        specialDayName: "",
        specialDayMessage: "",
        hasSpecialDay: false,
        labelTimeRemaining: "Vaktine Kalan Sure",
        labelTimeTo: "vaktine",
        labelCurrentTime: "Vakti",
        labelNowAt: "Su an",
        labelNowInTime: "vaktinde",
        labelImsak: "Imsak",
        labelGunes: "Gunes",
        labelOgle: "Ogle",
        labelIkindi: "Ikindi",
        labelAksam: "Aksam",
        labelYatsi: "Yatsi",
        backgroundKey: "orange",
        textColorHex: "FFFFFF",
        opacity: 1.0
    )

    static func load() -> WidgetData {
        let appGroupId = "group.com.kocabay.huzurvakti"
        let defaults = UserDefaults(suiteName: appGroupId)

        func string(_ key: String, _ fallback: String) -> String {
            defaults?.string(forKey: key) ?? fallback
        }

        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults?.object(forKey: key) as? Bool ?? fallback
        }

        func double(_ key: String, _ fallback: Double) -> Double {
            defaults?.object(forKey: key) as? Double ?? fallback
        }

        return WidgetData(
            nextPrayer: string("sonraki_vakit", "Sonraki Vakit"),
            nextTime: string("sonraki_vakit_saati", "--:--"),
            remaining: string("kalan_sure", "--"),
            remainingShort: string("kalan_kisa", "--"),
            currentPrayer: string("mevcut_vakit", ""),
            currentTime: string("mevcut_vakit_saati", ""),
            dateText: string("tarih", ""),
            dateShort: string("miladi_tarih", ""),
            hijriDate: string("hicri_tarih", ""),
            location: string("konum", ""),
            imsak: string("imsak_saati", ""),
            gunes: string("gunes_saati", ""),
            ogle: string("ogle_saati", ""),
            ikindi: string("ikindi_saati", ""),
            aksam: string("aksam_saati", ""),
            yatsi: string("yatsi_saati", ""),
            dailyQuote: string("gunun_sozu", ""),
            dailyQuoteSource: string("soz_kaynak", ""),
            esmaName: string("esma_turkce", ""),
            esmaMeaning: string("esma_anlam", ""),
            specialDayName: string("ozel_gun_adi", ""),
            specialDayMessage: string("ozel_gun_mesaj", ""),
            hasSpecialDay: bool("ozel_gun_var", false),
            labelTimeRemaining: string("widget_time_remaining", "Vaktine Kalan Sure"),
            labelTimeTo: string("widget_time_to", "vaktine"),
            labelCurrentTime: string("widget_current_time", "Vakti"),
            labelNowAt: string("widget_now_at", "Su an"),
            labelNowInTime: string("widget_now_in_time", "vaktinde"),
            labelImsak: string("label_imsak", "Imsak"),
            labelGunes: string("label_gunes", "Gunes"),
            labelOgle: string("label_ogle", "Ogle"),
            labelIkindi: string("label_ikindi", "Ikindi"),
            labelAksam: string("label_aksam", "Aksam"),
            labelYatsi: string("label_yatsi", "Yatsi"),
            backgroundKey: string("arkaplan_key", "orange"),
            textColorHex: string("yazi_rengi_hex", "FFFFFF"),
            opacity: double("seffaflik", 1.0)
        )
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }
        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
