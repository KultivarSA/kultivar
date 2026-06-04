// KultivarWidget.swift
// Kultivar — WidgetKit glance widget for iOS / iPadOS.
//
// ── How to add this to your Xcode project ──────────────────────────────────
//
//  1. In Xcode open Runner.xcworkspace (NOT .xcodeproj).
//  2. File → New → Target → "Widget Extension".
//     • Product Name : KultivarWidget
//     • Include Configuration Intent: OFF
//     • Language: Swift
//  3. Add the "App Groups" capability to BOTH the Runner target and the
//     KultivarWidget target with the group: group.io.kultivar.app
//     (Signing & Capabilities → + → App Groups → add the group).
//  4. Replace the generated Swift file with this file.
//  5. In the KultivarWidget/Info.plist set NSExtension → NSExtensionPrincipalClass
//     to KultivarWidgetBundle (Xcode usually sets this automatically).
//  6. Build & run.  Flutter's WidgetUpdateService will push data on every app
//     resume via HomeWidget.updateWidget().
//
// ── Data keys ──────────────────────────────────────────────────────────────
//  Keys written by WidgetUpdateService.dart (must stay in sync):
//    widget_space_name  — e.g. "Tent 1"
//    widget_temp        — e.g. "24.2°C"
//    widget_humidity    — e.g. "62%"
//    widget_vpd         — e.g. "1.22 kPa"
//    widget_vpd_status  — "ideal" | "high" | "low" | ""
//    widget_age         — e.g. "14m ago"
//    widget_next_care   — e.g. "Water in 2d — Blue Dream"
//    widget_plant_count — integer
//
// ── iOS App Group ───────────────────────────────────────────────────────────
//  home_widget stores data in the App Group's UserDefaults.
//  The group ID must match WidgetUpdateService._appGroupId in Dart.
// ──────────────────────────────────────────────────────────────────────────

import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupId = "group.io.kultivar.app"

private func widgetDefaults() -> UserDefaults {
    UserDefaults(suiteName: appGroupId) ?? .standard
}

// MARK: - Entry

struct KultivarEntry: TimelineEntry {
    let date: Date
    let spaceName:  String
    let temp:       String
    let humidity:   String
    let vpd:        String
    let vpdStatus:  String   // "ideal" | "high" | "low" | ""
    let age:        String
    let nextCare:   String
    let plantCount: Int
}

private extension KultivarEntry {
    static var placeholder: KultivarEntry {
        KultivarEntry(
            date:       Date(),
            spaceName:  "Tent 1",
            temp:       "24.2°C",
            humidity:   "62%",
            vpd:        "1.22 kPa",
            vpdStatus:  "ideal",
            age:        "5m ago",
            nextCare:   "Water in 2d — Blue Dream",
            plantCount: 2
        )
    }

    static func fromDefaults() -> KultivarEntry {
        let d = widgetDefaults()
        return KultivarEntry(
            date:       Date(),
            spaceName:  d.string(forKey: "widget_space_name")  ?? "—",
            temp:       d.string(forKey: "widget_temp")        ?? "—",
            humidity:   d.string(forKey: "widget_humidity")    ?? "—",
            vpd:        d.string(forKey: "widget_vpd")         ?? "—",
            vpdStatus:  d.string(forKey: "widget_vpd_status")  ?? "",
            age:        d.string(forKey: "widget_age")         ?? "—",
            nextCare:   d.string(forKey: "widget_next_care")   ?? "—",
            plantCount: d.integer(forKey: "widget_plant_count")
        )
    }
}

// MARK: - Timeline provider

struct KultivarProvider: TimelineProvider {
    func placeholder(in context: Context) -> KultivarEntry {
        .placeholder
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (KultivarEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .fromDefaults())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<KultivarEntry>) -> Void) {
        let entry = KultivarEntry.fromDefaults()
        // Refresh every 30 minutes as a fallback; Flutter also pushes on resume.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Colours

private extension Color {
    static let kultivarPrimary  = Color(red: 0.00, green: 0.78, blue: 0.59) // #00C896
    static let kultivarSurface  = Color(red: 0.07, green: 0.07, blue: 0.10) // #13131A
    static let kultivarBorder   = Color(red: 0.16, green: 0.16, blue: 0.24) // #2A2A3D
    static let kultivarMuted    = Color(red: 0.35, green: 0.35, blue: 0.44) // #5A5A70
    static let kultivarSecond   = Color(red: 0.56, green: 0.56, blue: 0.67) // #9090AA
    static let kultivarText     = Color(red: 0.94, green: 0.94, blue: 1.00) // #F0F0FF

    static func vpdColor(for status: String) -> Color {
        switch status {
        case "ideal": return .kultivarPrimary
        case "high":  return Color(red: 0.94, green: 0.27, blue: 0.40)  // #EF4565
        case "low":   return Color(red: 0.39, green: 0.71, blue: 0.96)  // #64B5F6
        default:      return .kultivarSecond
        }
    }
}

// MARK: - Widget view

struct KultivarWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: KultivarEntry

    var body: some View {
        ZStack {
            Color.kultivarSurface
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text(entry.spaceName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.kultivarPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.age)
                        .font(.system(size: 10))
                        .foregroundColor(.kultivarMuted)
                }

                Divider().background(Color.kultivarBorder)

                // Env readings
                HStack(spacing: 0) {
                    readingCell(value: entry.temp,     label: "Temp")
                    readingCell(value: entry.humidity, label: "RH")
                    vpdCell
                }

                Divider().background(Color.kultivarBorder)

                // Next care event
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                        .foregroundColor(.kultivarMuted)
                    Text(entry.nextCare)
                        .font(.system(size: 11))
                        .foregroundColor(.kultivarSecond)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .containerBackground(.kultivarSurface, for: .widget)
    }

    private func readingCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.kultivarText)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.kultivarMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vpdCell: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.vpd)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.vpdColor(for: entry.vpdStatus))
            Text(entry.vpdStatus.isEmpty ? "VPD" : "VPD · \(entry.vpdStatus)")
                .font(.system(size: 9))
                .foregroundColor(.kultivarMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget declaration

struct KultivarWidget: Widget {
    let kind = "KultivarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KultivarProvider()) { entry in
            KultivarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kultivar Glance")
        .description("Latest environment reading and next care event.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct KultivarWidgetBundle: WidgetBundle {
    var body: some Widget {
        KultivarWidget()
    }
}

// MARK: - Previews

#if DEBUG
struct KultivarWidget_Previews: PreviewProvider {
    static var previews: some View {
        KultivarWidgetEntryView(entry: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif
