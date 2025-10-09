# Google Maps Setup Guide

## 🗺️ Google Maps API Configuration

Your Safe Travel App now has Google Maps integration, but it requires a Google Maps API key to function properly.

## 📋 Setup Steps

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** 
   - **Geocoding API**
   - **Places API** (optional)

4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy your API key

### 2. Configure Android

Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyC4YourActualAPIKeyHere"/>
```

### 3. Configure iOS (if needed)

Add to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 🔧 Debugging Location Issues

### Check Permissions
The app requires location permissions. If not granted:
1. Go to Settings → Apps → Safe Travel App → Permissions
2. Enable Location permissions

### Debug Console Logs
Look for these logs in your console:
- `🔄 Initializing location service...`
- `📍 Getting current location...`
- `✅ Got location: lat, lng`
- `🗺️ Google Map created successfully`

### Common Issues

1. **"Loading Map..." stuck**
   - Check if API key is correct
   - Ensure Maps SDK for Android is enabled

2. **"Getting Location..." stuck**
   - Check location permissions
   - Enable GPS/location services
   - Try the "Retry Location" button

3. **Map shows but no markers**
   - Check console for marker creation logs
   - Verify location is being received

## 🚀 Testing

1. Build and run: `flutter build apk --debug`
2. Install APK and grant location permissions
3. Open map screen - should show:
   - Real Google Maps
   - Blue marker at your location
   - "Live Location" green badge
   - Your location should update as you move

## 💡 Features Working

✅ **Real Google Maps** - Native map tiles and interactions  
✅ **Live Location Tracking** - Blue marker follows your movement  
✅ **Location Permissions** - Proper Android permissions requested  
✅ **Status Badges** - Live location and connection indicators  
✅ **Retry Functionality** - Manual location refresh button  
✅ **Marker System** - Current location and nearby users  
✅ **Camera Tracking** - Map follows your movement smoothly  

## 🔐 Security Note

- Keep your API key secure
- Add restrictions in Google Cloud Console:
  - Android apps: Add your package name
  - HTTP referrers: Add your domain (for web)
  - API restrictions: Limit to required APIs only