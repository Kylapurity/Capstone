import 'package:poultry_app/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:poultry_app/screens/auth/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _chickenCountController = TextEditingController();
  bool _hidePassword = true;
  bool _isLoading = false;

  final authService = AuthService();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _chickenCountController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    // First validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final chickenCount = _chickenCountController.text.trim();

    try {
      await authService.signUpWithEmailPassword(
        email,
        password,
        chickenCount,
        username,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup successful!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to Login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final spacing = screenHeight * 0.02;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'lib/assets/images/Background.png',
            fit: BoxFit.cover,
            color: Colors.white30,
            colorBlendMode: BlendMode.lighten,
          ),

          // Hexagon at top left
          Positioned(
            top: -30,
            left: -40,
            child: Image.asset('lib/assets/images/Elesi.png', width: 150),
          ),

          // Hexagon at bottom right
          Positioned(
            bottom: -40,
            right: -50,
            child: Image.asset('lib/assets/images/Elesi.png', width: 150),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight - 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: spacing),

                        // Logo
                        Center(
                          child: Image.asset(
                            'lib/assets/images/poultry_app_logo.png',
                            width: 100,
                          ),
                        ),

                        SizedBox(height: spacing * 1.5),

                        // Signup Title
                        const Text(
                          'Sign up',
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 5),

                        // Subtitle
                        const Text(
                          'Enter your information',
                          style: TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 11),

                        // Signup Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Username field
                              const Text(
                                'Username',
                                style: TextStyle(
                                  fontFamily: 'Urbanist',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your username',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: spacing),

                              // Password field
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontFamily: 'Urbanist',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _hidePassword,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _hidePassword = !_hidePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: spacing),

                              // Email field
                              const Text(
                                'Email',
                                style: TextStyle(
                                  fontFamily: 'Urbanist',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Enter your email',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: spacing),

                              // Number of Chickens field
                              const Text(
                                'Number of Chickens',
                                style: TextStyle(
                                  fontFamily: 'Urbanist',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3A3A3A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _chickenCountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Enter number of chickens',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter number of chickens';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: spacing * 1.5),

                              // SIGNUP button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'SIGNUP',
                                          style: TextStyle(
                                            fontFamily: 'Urbanist',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Login link
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    'Already have an account? Login',
                                    style: TextStyle(
                                      fontFamily: 'Urbanist',
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}