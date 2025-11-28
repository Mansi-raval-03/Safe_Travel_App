import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let googleMapsApiKey = plist["GoogleMapsAPIKey"] as? String {
      GMSServices.provideAPIKey(googleMapsApiKey)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    // Expose maps API key to Dart via MethodChannel (matches Android MainActivity)
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let configChannel = FlutterMethodChannel(name: "safe_travel_app/config",
                          binaryMessenger: controller.binaryMessenger)
    configChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getMapsApiKey" {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let googleMapsApiKey = plist["GoogleMapsAPIKey"] as? String {
          result(googleMapsApiKey)
        } else {
          result("")
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
