import Flutter
import UIKit
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

private final class BufferedStringEventBridge: NSObject, FlutterStreamHandler {
  private let methodName: String
  private let eventName: String
  private var latestValue: String?
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?

  init(methodName: String, eventName: String) {
    self.methodName = methodName
    self.eventName = eventName
    super.init()
  }

  func configure(
    with messenger: FlutterBinaryMessenger,
    methodHandler: @escaping FlutterMethodCallHandler
  ) {
    guard methodChannel == nil, eventChannel == nil else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: methodName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler(methodHandler)
    self.methodChannel = methodChannel

    let eventChannel = FlutterEventChannel(
      name: eventName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)
    self.eventChannel = eventChannel
  }

  func publish(_ value: String?) {
    guard let value else {
      return
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }

    if let eventSink {
      eventSink(trimmed)
    } else {
      latestValue = trimmed
    }
  }

  func takeLatest() -> String? {
    defer { latestValue = nil }
    return latestValue
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private enum WidgetChannel {
    static let methodName = "mindrium/widget_launch"
    static let eventName = "mindrium/widget_launch_events"
  }

  private enum NotificationChannel {
    static let methodName = "mindrium/notification_launch"
    static let eventName = "mindrium/notification_launch_events"
  }

  private enum WidgetDefaultsKey {
    static let diaryCount = "mindrium_widget_diary_count"
    static let relaxationCount = "mindrium_widget_relaxation_count"
    static let completedWeeks = "mindrium_widget_completed_weeks"
  }

  static var shared: AppDelegate? {
    UIApplication.shared.delegate as? AppDelegate
  }

  private let widgetLaunchBridge = BufferedStringEventBridge(
    methodName: WidgetChannel.methodName,
    eventName: WidgetChannel.eventName
  )
  private let notificationLaunchBridge = BufferedStringEventBridge(
    methodName: NotificationChannel.methodName,
    eventName: NotificationChannel.eventName
  )

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureChannels(with: engineBridge.applicationRegistrar.messenger())
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleLaunchURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if handle(userActivity: userActivity) {
      return true
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  private func configureChannels(with messenger: FlutterBinaryMessenger) {
    configureWidgetChannels(with: messenger)
    configureNotificationChannels(with: messenger)
  }

  func handle(connectionOptions: UIScene.ConnectionOptions) {
    handle(urlContexts: connectionOptions.urlContexts)
    for activity in connectionOptions.userActivities {
      _ = handle(userActivity: activity)
    }
    if #available(iOS 13.0, *) {
      handle(notificationResponse: connectionOptions.notificationResponse)
    }
  }

  func handle(urlContexts: Set<UIOpenURLContext>) {
    for context in urlContexts {
      if handleLaunchURL(context.url) {
        break
      }
    }
  }

  @discardableResult
  func handle(userActivity: NSUserActivity) -> Bool {
    if let action = parseLaunchAction(from: userActivity) {
      publishLaunchAction(action)
      return true
    }
    return false
  }

  @discardableResult
  func handleLaunchURL(_ url: URL) -> Bool {
    guard let action = parseLaunchAction(from: url) else {
      return false
    }
    publishLaunchAction(action)
    return true
  }

  private func configureWidgetChannels(with messenger: FlutterBinaryMessenger) {
    widgetLaunchBridge.configure(with: messenger) { [weak self] call, result in
      self?.handleWidgetMethodCall(call, result: result)
    }
  }

  private func configureNotificationChannels(with messenger: FlutterBinaryMessenger) {
    notificationLaunchBridge.configure(with: messenger) { [weak self] call, result in
      self?.handleNotificationMethodCall(call, result: result)
    }
  }

  private func handleWidgetMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialLaunchAction":
      result(widgetLaunchBridge.takeLatest())
    case "updateWidgetStats":
      let arguments = call.arguments as? [String: Any]
      let diaryCount = Self.parseInt(arguments?["diaryCount"])
      let relaxationCount = Self.parseInt(arguments?["relaxationCount"])
      let completedWeeks = Self.parseInt(arguments?["completedWeeks"])
      persistWidgetStats(
        diaryCount: diaryCount,
        relaxationCount: relaxationCount,
        completedWeeks: completedWeeks
      )
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleNotificationMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialNotificationPayload":
      result(notificationLaunchBridge.takeLatest())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func persistWidgetStats(
    diaryCount: Int,
    relaxationCount: Int,
    completedWeeks: Int
  ) {
    let defaults = widgetDefaults()
    defaults.set(diaryCount, forKey: WidgetDefaultsKey.diaryCount)
    defaults.set(relaxationCount, forKey: WidgetDefaultsKey.relaxationCount)
    defaults.set(completedWeeks, forKey: WidgetDefaultsKey.completedWeeks)

    #if canImport(WidgetKit)
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    #endif
  }

  private func publishLaunchAction(_ action: String?) {
    widgetLaunchBridge.publish(action)
  }

  private func publishNotificationPayload(_ payload: String?) {
    notificationLaunchBridge.publish(payload)
  }

  @discardableResult
  func handle(notificationResponse: UNNotificationResponse?) -> Bool {
    handleNotificationResponse(notificationResponse, source: "scene")
  }

  private func notificationPayload(from userInfo: [AnyHashable: Any]) -> String? {
    if let payload = userInfo["payload"] as? String {
      return payload
    }
    if let payload = userInfo["Payload"] as? String {
      return payload
    }
    return nil
  }

  private func parseLaunchAction(from url: URL) -> String? {
    guard
      url.scheme?.lowercased() == "mindrium",
      url.host?.lowercased() == "widget"
    else {
      return nil
    }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    return queryItems
      .first { item in
        item.name == "action" || item.name == "launch_action"
      }?
      .value?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func parseLaunchAction(from userActivity: NSUserActivity) -> String? {
    if let url = userActivity.webpageURL, let action = parseLaunchAction(from: url) {
      return action
    }

    if let action = userActivity.userInfo?["launch_action"] as? String {
      return action.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let action = userActivity.userInfo?["action"] as? String {
      return action.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return nil
  }

  private func widgetDefaults() -> UserDefaults {
    guard
      let appGroup = Bundle.main.object(
        forInfoDictionaryKey: "MindriumWidgetAppGroup"
      ) as? String,
      !appGroup.isEmpty,
      let sharedDefaults = UserDefaults(suiteName: appGroup)
    else {
      return .standard
    }

    return sharedDefaults
  }

  private static func parseInt(_ value: Any?) -> Int {
    switch value {
    case let intValue as Int:
      return intValue
    case let numberValue as NSNumber:
      return numberValue.intValue
    case let stringValue as String:
      return Int(stringValue) ?? 0
    default:
      return 0
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    _ = handleNotificationResponse(response, source: "delegate")

    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  @discardableResult
  private func handleNotificationResponse(
    _ response: UNNotificationResponse?,
    source: String
  ) -> Bool {
    guard let response else {
      return false
    }

    let payload = notificationPayload(from: response.notification.request.content.userInfo)
    if let payload {
      print("[NotificationTap][iOS][\(source)] payload=\(payload)")
      publishNotificationPayload(payload)
      return true
    }

    print("[NotificationTap][iOS][\(source)] payload missing")
    return false
  }
}
