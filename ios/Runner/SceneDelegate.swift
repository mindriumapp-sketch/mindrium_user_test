import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    AppDelegate.shared?.handle(connectionOptions: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    AppDelegate.shared?.handle(urlContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    AppDelegate.shared?.handle(userActivity: userActivity)
  }
}
