import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_trip_planner/screens/home_screen.dart';
import 'package:smart_trip_planner/screens/login_screen.dart';
import 'package:smart_trip_planner/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Signupscreen extends StatefulWidget {
  Signupscreen({super.key});

  @override
  State<Signupscreen> createState() => _SignupscreenState();
}

class _SignupscreenState extends State<Signupscreen> {
  bool _hidepass = true;
  final AuthService _auth = AuthService();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.flight,
                    size: 40,
                    color: Color.fromARGB(255, 234, 196, 8),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    'Itinera AI',
                    style: TextStyle(
                      color: Color.fromARGB(255, 17, 135, 2),
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'Create your Account',
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.w700),
              ),
              const Text('Let\'s get started', style: TextStyle(fontSize: 14)),
              const Spacer(),

              // Inside your Column where the Google button is:
              Center(
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _signUpWithGoogle,
                    icon: Image.asset(
                      'assets/images/google-icon.png',
                      height: 20,
                    ),
                    label: const Text(
                      'Sign up with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '------------------- or Sign up with Gmail -------------------',
                style: TextStyle(
                  fontWeight: FontWeight.w200,
                  color: Color.fromARGB(255, 11, 10, 10),
                ),
              ),
              const Spacer(),

              const Text('Email address'),
              SizedBox(
                height: 40,
                width: 300,
                child: TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Spacer(),

              const Text('Password'),
              SizedBox(
                height: 40,
                width: 300,
                child: TextField(
                  obscureText: _hidepass,
                  controller: _password,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidepass = !_hidepass),
                      icon: Icon(
                        _hidepass ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const Spacer(),

              const Text('Confirm Password'),
              SizedBox(
                height: 40,
                width: 300,
                child: TextField(
                  obscureText: _hidepass,
                  controller: _confirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidepass = !_hidepass),
                      icon: Icon(
                        _hidepass ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const Spacer(),

              ElevatedButton(
                style: const ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(Colors.green),
                ),
                onPressed: _signUp,
                child: const Text(
                  'Sign Up',
                  style: TextStyle(color: Colors.white),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Have an account?'),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Color.fromARGB(255, 7, 47, 221)),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ Normal Email/Password Sign Up ------------------
  void _signUp() async {
    String email = _email.text.trim();
    String password = _password.text.trim();
    String confirmPassword = _confirmPassword.text.trim();

    if (password != confirmPassword) {
      _showSnackbar('Passwords don\'t match');
      return;
    }

    try {
      User? user = await _auth.signUpWithEmailAndPassword(email, password);

      if (!context.mounted) return;

      if (user != null) {
        _showSnackbar('User successfully created');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        _showSnackbar('Sign up failed');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = switch (e.code) {
        'email-already-in-use' => 'Email is already in use',
        'invalid-email' => 'Invalid email address',
        'operation-not-allowed' => 'Email/password accounts are not enabled',
        'weak-password' => 'Password is too weak',
        _ => 'Signup failed: ${e.code}',
      };
      _showSnackbar(errorMessage);
    } catch (e) {
      _showSnackbar('Something went wrong: $e');
    }
  }

  // ------------------ Google Sign Up ------------------
  void _signUpWithGoogle() async {
    try {
      final user = await _auth.signInWithGoogle(
        webClientId:
            '269088732896-08v3gno7q0p8nel1fltda70gbgefl2eo.apps.googleusercontent.com',
      );
      if (user != null) {
        if (!mounted) return;
        _showSnackbar('Welcome ${user.displayName ?? 'User'}!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        _showSnackbar('Google sign-up canceled');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackbar('Google sign-up failed: ${e.code}');
    } catch (e) {
      _showSnackbar('Something went wrong: $e');
    }
  }

  // ------------------ Snackbar ------------------
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }
}
