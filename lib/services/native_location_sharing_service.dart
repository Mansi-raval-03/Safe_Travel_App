import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

/// Service for native platform-specific location sharing
class NativeLocationSharingService {
  static final NativeLocationSharingService _instance = NativeLocationSharingService._internal();
  factory NativeLocationSharingService() => _instance;
  NativeLocationSharingService._internal();

  /// Share location via WhatsApp with native location
  Future<bool> shareLocationViaWhatsApp(Position position, {String? message}) async {
    try {
      // WhatsApp location sharing URL scheme
      // For Android: whatsapp://send?location=lat,lng
      // For iOS: whatsapp://send?location=lat,lng
      final lat = position.latitude;
      final lng = position.longitude;
      
      String whatsappUrl;
      
      if (Platform.isAndroid) {
        // Android WhatsApp location sharing
        whatsappUrl = 'whatsapp://send?location=$lat,$lng';
        if (message != null && message.isNotEmpty) {
          whatsappUrl += '&text=${Uri.encodeComponent(message)}';
        }
      } else if (Platform.isIOS) {
        // iOS WhatsApp location sharing
        whatsappUrl = 'whatsapp://send?location=$lat,$lng';
        if (message != null && message.isNotEmpty) {
          whatsappUrl += '&text=${Uri.encodeComponent(message)}';
        }
      } else {
        // Web fallback - use WhatsApp Web
        whatsappUrl = 'https://web.whatsapp.com/send?text=${Uri.encodeComponent(
          "${message ?? 'Sharing my location'} https://maps.google.com/maps?q=$lat,$lng"
        )}';
      }

      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via WhatsApp');
        return true;
      } else {
        print('❌ WhatsApp not installed or cannot handle location sharing');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via WhatsApp: $e');
      return false;
    }
  }

  /// Share location via Google Maps
  Future<bool> shareLocationViaGoogleMaps(Position position, {String? message}) async {
    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      String mapsUrl;
      
      if (Platform.isAndroid) {
        // Android Google Maps intent
        mapsUrl = 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(message ?? 'Current Location')})';
      } else if (Platform.isIOS) {
        // iOS Google Maps URL scheme
        mapsUrl = 'comgooglemaps://?q=$lat,$lng&center=$lat,$lng&zoom=15';
      } else {
        // Web - use Google Maps web
        mapsUrl = 'https://maps.google.com/maps?q=$lat,$lng&z=15';
      }

      final uri = Uri.parse(mapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via Google Maps');
        return true;
      } else {
        // Fallback to web Google Maps
        final webUrl = 'https://maps.google.com/maps?q=$lat,$lng&z=15';
        final webUri = Uri.parse(webUrl);
        await launchUrl(webUri);
        print('✅ Location shared via Google Maps (web)');
        return true;
      }
    } catch (e) {
      print('❌ Error sharing location via Google Maps: $e');
      return false;
    }
  }

  /// Share location via Apple Maps (iOS only)
  Future<bool> shareLocationViaAppleMaps(Position position, {String? message}) async {
    if (!Platform.isIOS) {
      print('❌ Apple Maps only available on iOS');
      return false;
    }

    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      // Apple Maps URL scheme
      final mapsUrl = 'maps://?q=${Uri.encodeComponent(message ?? 'Current Location')}&ll=$lat,$lng&z=15';
      
      final uri = Uri.parse(mapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via Apple Maps');
        return true;
      } else {
        print('❌ Apple Maps not available');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via Apple Maps: $e');
      return false;
    }
  }

  /// Share location via Telegram
  Future<bool> shareLocationViaTelegram(Position position, {String? message}) async {
    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      String telegramUrl;
      
      if (Platform.isAndroid || Platform.isIOS) {
        // Telegram location sharing URL scheme
        telegramUrl = 'tg://msg?text=${Uri.encodeComponent(
          "${message ?? 'Sharing my location'} https://maps.google.com/maps?q=$lat,$lng"
        )}';
      } else {
        // Web Telegram
        telegramUrl = 'https://t.me/share/url?url=${Uri.encodeComponent(
          "https://maps.google.com/maps?q=$lat,$lng"
        )}&text=${Uri.encodeComponent(message ?? 'Sharing my location')}';
      }

      final uri = Uri.parse(telegramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via Telegram');
        return true;
      } else {
        print('❌ Telegram not installed');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via Telegram: $e');
      return false;
    }
  }

  /// Share location via SMS
  Future<bool> shareLocationViaSMS(Position position, {String? message, String? phoneNumber}) async {
    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      final locationText = "${message ?? 'I\'m sharing my location with you:'} https://maps.google.com/maps?q=$lat,$lng";
      
      String smsUrl;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        smsUrl = 'sms:$phoneNumber?body=${Uri.encodeComponent(locationText)}';
      } else {
        smsUrl = 'sms:?body=${Uri.encodeComponent(locationText)}';
      }

      final uri = Uri.parse(smsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via SMS');
        return true;
      } else {
        print('❌ SMS not available');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via SMS: $e');
      return false;
    }
  }

  /// Share location via Email
  Future<bool> shareLocationViaEmail(Position position, {String? message, String? emailAddress}) async {
    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      final subject = 'Live Location Sharing - Safe Travel';
      final body = """
${message ?? 'I\'m sharing my live location with you.'}

📍 Location: $lat, $lng
🗺️ View on Maps: https://maps.google.com/maps?q=$lat,$lng
📱 Shared via Safe Travel App

Click the map link to view my current location.
""";

      String emailUrl;
      if (emailAddress != null && emailAddress.isNotEmpty) {
        emailUrl = 'mailto:$emailAddress?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      } else {
        emailUrl = 'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      }

      final uri = Uri.parse(emailUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via Email');
        return true;
      } else {
        print('❌ Email not available');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via Email: $e');
      return false;
    }
  }

  /// Share location via Messenger
  Future<bool> shareLocationViaMessenger(Position position, {String? message}) async {
    try {
      final lat = position.latitude;
      final lng = position.longitude;
      
      String messengerUrl;
      
      if (Platform.isAndroid || Platform.isIOS) {
        // Facebook Messenger URL scheme
        messengerUrl = 'fb-messenger://share?text=${Uri.encodeComponent(
          "${message ?? 'Sharing my location'} https://maps.google.com/maps?q=$lat,$lng"
        )}';
      } else {
        // Web Messenger
        messengerUrl = 'https://www.messenger.com/new?text=${Uri.encodeComponent(
          "${message ?? 'Sharing my location'} https://maps.google.com/maps?q=$lat,$lng"
        )}';
      }

      final uri = Uri.parse(messengerUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ Location shared via Messenger');
        return true;
      } else {
        print('❌ Messenger not installed');
        return false;
      }
    } catch (e) {
      print('❌ Error sharing location via Messenger: $e');
      return false;
    }
  }

  /// Check if a specific app is available for location sharing
  Future<bool> isAppAvailable(String app) async {
    try {
      String testUrl;
      
      switch (app.toLowerCase()) {
        case 'whatsapp':
          testUrl = 'whatsapp://';
          break;
        case 'telegram':
          testUrl = 'tg://';
          break;
        case 'messenger':
          testUrl = 'fb-messenger://';
          break;
        case 'googlemaps':
          if (Platform.isAndroid) {
            testUrl = 'geo:0,0';
          } else if (Platform.isIOS) {
            testUrl = 'comgooglemaps://';
          } else {
            return true; // Always available on web
          }
          break;
        case 'applemaps':
          if (Platform.isIOS) {
            testUrl = 'maps://';
          } else {
            return false; // Only available on iOS
          }
          break;
        case 'sms':
          testUrl = 'sms:';
          break;
        case 'email':
          testUrl = 'mailto:';
          break;
        default:
          return false;
      }
      
      final uri = Uri.parse(testUrl);
      return await canLaunchUrl(uri);
    } catch (e) {
      print('❌ Error checking app availability for $app: $e');
      return false;
    }
  }

  /// Get list of available sharing options
  Future<List<SharingOption>> getAvailableSharingOptions() async {
    List<SharingOption> options = [];
    
    // Check WhatsApp
    if (await isAppAvailable('whatsapp')) {
      options.add(SharingOption(
        id: 'whatsapp',
        name: 'WhatsApp',
        icon: '💬',
        description: 'Share live location via WhatsApp',
        isNativeLocation: true,
      ));
    }
    
    // Check Telegram
    if (await isAppAvailable('telegram')) {
      options.add(SharingOption(
        id: 'telegram',
        name: 'Telegram',
        icon: '✈️',
        description: 'Share location via Telegram',
        isNativeLocation: false,
      ));
    }
    
    // Check Messenger
    if (await isAppAvailable('messenger')) {
      options.add(SharingOption(
        id: 'messenger',
        name: 'Messenger',
        icon: '📧',
        description: 'Share location via Facebook Messenger',
        isNativeLocation: false,
      ));
    }
    
    // Google Maps (usually always available)
    options.add(SharingOption(
      id: 'googlemaps',
      name: 'Google Maps',
      icon: '🗺️',
      description: 'Open location in Google Maps',
      isNativeLocation: true,
    ));
    
    // Apple Maps (iOS only)
    if (Platform.isIOS && await isAppAvailable('applemaps')) {
      options.add(SharingOption(
        id: 'applemaps',
        name: 'Apple Maps',
        icon: '🍎',
        description: 'Open location in Apple Maps',
        isNativeLocation: true,
      ));
    }
    
    // SMS (usually always available)
    if (await isAppAvailable('sms')) {
      options.add(SharingOption(
        id: 'sms',
        name: 'SMS',
        icon: '💬',
        description: 'Share location via text message',
        isNativeLocation: false,
      ));
    }
    
    // Email (usually always available)
    if (await isAppAvailable('email')) {
      options.add(SharingOption(
        id: 'email',
        name: 'Email',
        icon: '📧',
        description: 'Share location via email',
        isNativeLocation: false,
      ));
    }
    
    return options;
  }

  /// Share location using specified app
  Future<bool> shareLocationViaApp(String appId, Position position, {String? message}) async {
    switch (appId.toLowerCase()) {
      case 'whatsapp':
        return await shareLocationViaWhatsApp(position, message: message);
      case 'telegram':
        return await shareLocationViaTelegram(position, message: message);
      case 'messenger':
        return await shareLocationViaMessenger(position, message: message);
      case 'googlemaps':
        return await shareLocationViaGoogleMaps(position, message: message);
      case 'applemaps':
        return await shareLocationViaAppleMaps(position, message: message);
      case 'sms':
        return await shareLocationViaSMS(position, message: message);
      case 'email':
        return await shareLocationViaEmail(position, message: message);
      default:
        print('❌ Unknown app: $appId');
        return false;
    }
  }
}

/// Represents a sharing option
class SharingOption {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isNativeLocation; // true if app supports native location sharing

  SharingOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.isNativeLocation,
  });
}