import Flutter
import UIKit
import background_location_tracker
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register plugins for background execution - this method is deprecated
        // but kept for backward compatibility
        BackgroundLocationTrackerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        WorkmanagerPlugin.registerBGProcessingTask(
            withIdentifier: "com.example.poc_gps_bateaux.processing_task"
        )
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
