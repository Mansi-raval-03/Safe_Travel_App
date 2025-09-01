import 'package:supabase_flutter/supabase_flutter.dart';


class SupabaseService {
SupabaseService._();
static final SupabaseService _i = SupabaseService._();
factory SupabaseService() => _i;


final SupabaseClient _sb = Supabase.instance.client;


// ---------- AUTH ----------
Future<AuthResponse> signUpEmail({
required String email,
required String password,
String? fullName,
String? phone,
}) async {
final res = await _sb.auth.signUp(email: email, password: password);
final userId = res.user?.id;
if (userId != null) {
await _sb.from('profiles').upsert({
'id': userId,
'full_name': fullName,
'phone': phone,
});
}
return res;
}


Future<AuthResponse> signInEmail({
required String email,
required String password,
}) => _sb.auth.signInWithPassword(email: email, password: password);


Future<void> signOut() => _sb.auth.signOut();


String? get currentUserId => _sb.auth.currentUser?.id;


// ---------- PROFILES ----------
Future<Map<String, dynamic>?> fetchMyProfile() async {
final uid = currentUserId; if (uid == null) return null;
final rows = await _sb.from('profiles').select().eq('id', uid).maybeSingle();
return rows;
}


Future<void> updateMyProfile({String? fullName, String? phone}) async {
final uid = currentUserId; if (uid == null) return;
await _sb.from('profiles').update({
if (fullName != null) 'full_name': fullName,
if (phone != null) 'phone': phone,
}).eq('id', uid);
}


// ---------- CONTACTS ----------
}