import SwiftUI
import WidgetKit

private enum MindriumWidgetDefaultsKey {
  static let diaryCount = "mindrium_widget_diary_count"
  static let relaxationCount = "mindrium_widget_relaxation_count"
  static let completedWeeks = "mindrium_widget_completed_weeks"
}

private enum MindriumWidgetConfig {
  static let unlockWeek = 2
  static let fallbackAppGroup = "group.com.mindrium.gad_app.widget"
  static let launchURL = URL(string: "mindrium://widget?action=start_apply")!
}

private struct MindriumWidgetEntry: TimelineEntry {
  let date: Date
  let diaryCount: Int
  let relaxationCount: Int
  let completedWeeks: Int

  var isUnlocked: Bool {
    completedWeeks >= MindriumWidgetConfig.unlockWeek
  }

  var titleText: String {
    isUnlocked ? "Relief" : "2주차 완료 후 이용 가능"
  }

  var tagText: String {
    isUnlocked ? "READY" : "LOCKED"
  }

  var statsText: String {
    if isUnlocked {
      return "일기 \(diaryCount)건 · 이완 \(relaxationCount)회"
    }

    return "2주차 교육 완료 후 Relief를 바로 시작할 수 있어요."
  }

  var ctaText: String {
    isUnlocked ? "지금 시작" : "교육 먼저 하기"
  }
}

private struct MindriumWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> MindriumWidgetEntry {
    MindriumWidgetEntry(
      date: Date(),
      diaryCount: 3,
      relaxationCount: 5,
      completedWeeks: 2
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (MindriumWidgetEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MindriumWidgetEntry>) -> Void) {
    let entry = loadEntry()
    let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(refreshDate)))
  }

  private func loadEntry(date: Date = Date()) -> MindriumWidgetEntry {
    let defaults = widgetDefaults()
    return MindriumWidgetEntry(
      date: date,
      diaryCount: defaults.integer(forKey: MindriumWidgetDefaultsKey.diaryCount),
      relaxationCount: defaults.integer(forKey: MindriumWidgetDefaultsKey.relaxationCount),
      completedWeeks: defaults.integer(forKey: MindriumWidgetDefaultsKey.completedWeeks)
    )
  }

  private func widgetDefaults() -> UserDefaults {
    if
      let appGroup = Bundle.main.object(
        forInfoDictionaryKey: "MindriumWidgetAppGroup"
      ) as? String,
      !appGroup.isEmpty,
      let sharedDefaults = UserDefaults(suiteName: appGroup)
    {
      return sharedDefaults
    }

    if let sharedDefaults = UserDefaults(suiteName: MindriumWidgetConfig.fallbackAppGroup) {
      return sharedDefaults
    }

    return .standard
  }
}

private struct MindriumQuickApplyWidgetView: View {
  let entry: MindriumWidgetEntry

  private var titleColor: Color {
    entry.isUnlocked ? Color(hex: 0x132D4A) : Color(hex: 0x3A4B5D)
  }

  private var bodyColor: Color {
    entry.isUnlocked ? Color(hex: 0x1F3D5C) : Color(hex: 0x5D6A78)
  }

  private var badgeColor: Color {
    entry.isUnlocked ? Color(hex: 0x2A6FB0) : Color(hex: 0x6B7684)
  }

  private var buttonTextColor: Color {
    entry.isUnlocked ? .white : Color(hex: 0x5C6D81)
  }

  private var buttonBackgroundColor: Color {
    entry.isUnlocked ? Color(hex: 0x2A6FB0) : Color(hex: 0xD8E0E8)
  }

  private var badgeBackgroundColor: Color {
    entry.isUnlocked ? Color(hex: 0xD7EBFF) : Color(hex: 0xE8EDF2)
  }

  var body: some View {
    let content = VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Text(entry.tagText)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(badgeColor)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            Capsule()
              .fill(badgeBackgroundColor)
          )

        Spacer(minLength: 12)

        Text("Mindrium")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(bodyColor.opacity(0.8))
      }

      Spacer(minLength: 0)

      Text(entry.titleText)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(titleColor)
        .lineLimit(2)

      Text(entry.statsText)
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(bodyColor)
        .lineLimit(3)
        .multilineTextAlignment(.leading)

      Spacer(minLength: 0)

      HStack {
        Spacer(minLength: 0)

        Text(entry.ctaText)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(buttonTextColor)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(
            Capsule()
              .fill(buttonBackgroundColor)
          )
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(MindriumWidgetConfig.launchURL)

    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) {
        MindriumWidgetBackground(isUnlocked: entry.isUnlocked)
      }
    } else {
      content.background(MindriumWidgetBackground(isUnlocked: entry.isUnlocked))
    }
  }
}

private struct MindriumWidgetBackground: View {
  let isUnlocked: Bool

  var body: some View {
    LinearGradient(
      colors: isUnlocked
        ? [Color(hex: 0xF2F8FF), Color(hex: 0xDDEEFF)]
        : [Color(hex: 0xF3F5F7), Color(hex: 0xE5EAF0)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private struct MindriumQuickApplyWidget: Widget {
  let kind = "MindriumQuickApplyWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MindriumWidgetProvider()) { entry in
      MindriumQuickApplyWidgetView(entry: entry)
    }
    .configurationDisplayName("Mindrium Quick Apply")
    .description("홈 화면에서 바로 Relief 진입 상태를 확인하고 시작합니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct MindriumWidgetBundle: WidgetBundle {
  var body: some Widget {
    MindriumQuickApplyWidget()
  }
}

private extension Color {
  init(hex: UInt32, opacity: Double = 1.0) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255.0,
      green: Double((hex >> 8) & 0xFF) / 255.0,
      blue: Double(hex & 0xFF) / 255.0,
      opacity: opacity
    )
  }
}
