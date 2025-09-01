import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  final SupabaseClient _sb = Supabase.instance.client;

  // ======================================================
  // AUTHENTICATION
  // ======================================================

  /// Sign up new user with email & password
  Future<AuthResponse> signUpEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      final res = await _sb.auth.signUp(email: email, password: password);
      final userId = res.user?.id;

      // create profile row for new user
      if (userId != null) {
        await _sb.from('profiles').upsert({
          'id': userId,
          'full_name': fullName,
          'phone': phone,
        });
      }
      return res;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Sign in with email & password
  Future<AuthResponse> signInEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _sb.auth
          .signInWithPassword(email: email, password: password);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _sb.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Current logged in user ID
  String? get currentUserId => _sb.auth.currentUser?.id;

  // ======================================================
  // PROFILES
  // ======================================================

  /// Fetch current user's profile
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      return await _sb.from('profiles').select().eq('id', uid).maybeSingle();
    } catch (e) {
      throw Exception('Fetch profile failed: $e');
    }
  }

  /// Update current user's profile
  Future<void> updateMyProfile({
    String? fullName,
    String? phone,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _sb.from('profiles').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
      }).eq('id', uid);
    } catch (e) {
      throw Exception('Update profile failed: $e');
    }
  }

  // ======================================================
  // EMERGENCY CONTACTS
  // ======================================================

  /// List all emergency contacts for current user
  Future<List<Map<String, dynamic>>> listContacts() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      return await _sb
          .from('emergency_contacts')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
    } catch (e) {
      throw Exception('Fetch contacts failed: $e');
    }
  }

  /// Add a new emergency contact
  Future<void> addContact({
    required String name,
    required String phone,
    String? relation,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    try {
      await _sb.from('emergency_contacts').insert({
        'user_id': uid,
        'name': name,
        'phone': phone,
        'relation': relation,
      });
    } catch (e) {
      throw Exception('Add contact failed: $e');
    }
  }

  /// Delete a contact by its ID
  Future<void> deleteContact(int id) async {
    try {
      await _sb.from('emergency_contacts').delete().eq('id', id);
    } catch (e) {
      throw Exception('Delete contact failed: $e');
    }
  }

  // ======================================================
  // SOS ALERTS
  // ======================================================

  /// Create a new SOS alert
  Future<void> createSos({
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    try {
      await _sb.from('sos_alerts').insert({
        'user_id': uid,
        'latitude': latitude,
        'longitude': longitude,
        'message': message ?? 'Emergency! Need help.',
      });
    } catch (e) {
      throw Exception('Create SOS failed: $e');
    }
  }

  /// Fetch SOS history for current user
  Future<List<Map<String, dynamic>>> mySosHistory() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      return await _sb
          .from('sos_alerts')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
    } catch (e) {
      throw Exception('Fetch SOS history failed: $e');
    }
  }
}
