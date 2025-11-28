package com.example.safe_travel_app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safe_travel_app/config").setMethodCallHandler { call, result ->
			if (call.method == "getMapsApiKey") {
				try {
					val ai = applicationContext.packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
					val key = ai.metaData.getString("com.google.android.geo.API_KEY") ?: ""
					result.success(key)
				} catch (e: Exception) {
					result.error("NO_KEY", "Failed to read API key from manifest", null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
