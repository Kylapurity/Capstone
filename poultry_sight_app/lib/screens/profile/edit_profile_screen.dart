import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:poultry_app/services/user_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserProfileService _profileService = UserProfileService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _nameController.text = user.userMetadata?['username'] as String? ?? 'Farmer';
        _emailController.text = user.email ?? '';
      }

      final profile = await _profileService.getUserProfile();
      if (profile != null) {
        _farmNameController.text = profile['farm_name'] as String? ?? '';
        _phoneController.text = profile['phone_number'] as String? ?? '';
        _locationController.text = profile['location'] as String? ?? '';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile data';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Update profile in user_profiles table
      await _profileService.updateProfile(
        farmName: _farmNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        location: _locationController.text.trim(),
      );

      // Update user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': _nameController.text.trim(),
          },
        ),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _farmNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    _buildTextField(
                      controller: _nameController,
                      label: 'Name',
                      icon: Icons.person_outline,
                      hint: 'Enter your name',
                      enabled: true,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      hint: 'Enter your email',
                      enabled: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _farmNameController,
                      label: 'Farm Name',
                      icon: Icons.home_outlined,
                      hint: 'Enter farm name',
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      icon: Icons.location_on_outlined,
                      hint: 'Enter location',
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontFamily: 'Urbanist',
            ),
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            fontFamily: 'Urbanist',
            fontSize: 15,
            color: Colors.black87,
          ),
          validator: enabled && label == 'Name'
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}

