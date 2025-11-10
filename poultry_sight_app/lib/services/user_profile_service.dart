import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class UserProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in');
      return null;
    }

    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return response;
      }

      // If no profile exists, create one with default values
      return await createUserProfile(
        chickenCount: 100,
        farmName: 'My Farm',
      );
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Create user profile
  Future<Map<String, dynamic>> createUserProfile({
    int chickenCount = 100,
    String? farmName,
    String? phoneNumber,
    String? location,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase.from('user_profiles').insert({
        'id': user.id,
        'chicken_count': chickenCount,
        'farm_name': farmName,
        'phone_number': phoneNumber,
        'location': location,
      }).select().single();

      debugPrint('✅ User profile created');
      return response;
    } catch (e) {
      debugPrint('❌ Error creating user profile: $e');
      rethrow;
    }
  }

  /// Update chicken count
  Future<void> updateChickenCount(int count) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase.from('user_profiles').update({
        'chicken_count': count,
      }).eq('id', user.id);

      debugPrint('✅ Chicken count updated to $count');
    } catch (e) {
      debugPrint('❌ Error updating chicken count: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    int? chickenCount,
    String? farmName,
    String? phoneNumber,
    String? location,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final Map<String, dynamic> updateData = {};
      
      if (chickenCount != null) updateData['chicken_count'] = chickenCount;
      if (farmName != null) updateData['farm_name'] = farmName;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (location != null) updateData['location'] = location;

      await _supabase.from('user_profiles').update(updateData).eq('id', user.id);

      debugPrint('✅ User profile updated');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// Get chicken count (fallback to default if not set)
  Future<int> getChickenCount() async {
    final profile = await getUserProfile();
    return profile?['chicken_count'] as int? ?? 100;
  }
}

