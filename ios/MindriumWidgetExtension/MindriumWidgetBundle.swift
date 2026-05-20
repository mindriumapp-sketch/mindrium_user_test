import SwiftUI
import WidgetKit

private enum MindriumWidgetDefaultsKey {
  static let diaryCount = "mindrium_widget_diary_count"
  static let relaxationCount = "mindrium_widget_relaxation_count"
  static let completedWeeks = "mindrium_widget_completed_weeks"
}

private enum MindriumWidgetConfig {
  static let unlockWeek = 2
  static let fallbackAppGroup = "group.com.mindrium.gadApp.widget"
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

    return "교육·이완을 끝내면 Relief가 열려요."
  }

  var ctaText: String {
    isUnlocked ? "시작하기" : "교육 먼저"
  }
}

private struct MindriumWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> MindriumWidgetEntry {
    loadEntry()
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
  @Environment(\.widgetFamily) private var family

  let entry: MindriumWidgetEntry

  private var accentColor: Color {
    entry.isUnlocked ? Color(hex: 0x2E7EC8) : Color(hex: 0x7A8794)
  }

  private var titleColor: Color {
    entry.isUnlocked ? Color(hex: 0x0F3558) : Color(hex: 0x314457)
  }

  private var bodyColor: Color {
    entry.isUnlocked ? Color(hex: 0x315170) : Color(hex: 0x667482)
  }

  private var badgeColor: Color {
    entry.isUnlocked ? Color(hex: 0x1F6FB7) : Color(hex: 0x687481)
  }

  private var buttonTextColor: Color {
    entry.isUnlocked ? .white : Color(hex: 0x526170)
  }

  private var buttonBackgroundColor: Color {
    entry.isUnlocked ? Color(hex: 0x2179CE) : Color(hex: 0xDDE5ED)
  }

  private var badgeBackgroundColor: Color {
    entry.isUnlocked ? Color(hex: 0xE3F1FF) : Color(hex: 0xEEF2F5)
  }

  private var contentPadding: EdgeInsets {
    family == .systemMedium
      ? EdgeInsets(top: 14, leading: 15, bottom: 13, trailing: 15)
      : EdgeInsets(top: 13, leading: 13, bottom: 12, trailing: 13)
  }

  private var titleFontSize: CGFloat {
    if family == .systemMedium {
      return entry.isUnlocked ? 24 : 21
    }
    return entry.isUnlocked ? 22 : 18
  }

  private var titleLineLimit: Int {
    entry.isUnlocked ? 1 : 2
  }

  var body: some View {
    let content = widgetContent
    .padding(contentPadding)
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

  @ViewBuilder
  private var widgetContent: some View {
    if family == .systemMedium {
      HStack(alignment: .bottom, spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          header
          Spacer(minLength: 6)
          titleBlock
        }

        Spacer(minLength: 6)
        cta
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        header
        Spacer(minLength: 2)
        titleBlock
        Spacer(minLength: 4)
        HStack {
          Spacer(minLength: 0)
          cta
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 8) {
      HStack(spacing: 6) {
        Circle()
          .fill(accentColor)
          .frame(width: 5, height: 5)

        Text(entry.tagText)
          .font(.system(size: 10, weight: .bold))
      }
      .foregroundColor(badgeColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Capsule().fill(badgeBackgroundColor))

      Spacer(minLength: 8)

      Text("Mindrium")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(bodyColor.opacity(0.72))
    }
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.titleText)
        .font(.system(size: titleFontSize, weight: .bold))
        .foregroundColor(titleColor)
        .lineLimit(titleLineLimit)
        .minimumScaleFactor(0.86)

      Text(entry.statsText)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(bodyColor)
        .lineLimit(entry.isUnlocked ? 1 : 2)
        .minimumScaleFactor(0.9)
    }
  }

  private var cta: some View {
    HStack(spacing: 5) {
      Text(entry.ctaText)
        .font(.system(size: 12, weight: .bold))

      Image(systemName: "chevron.right")
        .font(.system(size: 10, weight: .bold))
    }
    .foregroundColor(buttonTextColor)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule()
        .fill(buttonBackgroundColor)
        .shadow(
          color: entry.isUnlocked ? accentColor.opacity(0.18) : .clear,
          radius: 3,
          x: 0,
          y: 2
        )
    )
  }
}

private struct MindriumWidgetBackground: View {
  let isUnlocked: Bool

  var body: some View {
    LinearGradient(
      colors: isUnlocked
        ? [Color(hex: 0xF7FBFF), Color(hex: 0xE8F4FF), Color(hex: 0xFFF8EF)]
        : [Color(hex: 0xF9FAFB), Color(hex: 0xEEF2F5), Color(hex: 0xF7F3EE)],
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
